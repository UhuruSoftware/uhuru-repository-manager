require 'steno'
require 'config'
require 'thin'
require 'optparse'
require 'vcap/common'
require 'vcap/config'

module Uhuru::RepositoryManager
# Entry class for the WebUI service
  class Runner
    def initialize(argv)
      @argv = argv

      # default config path. this may be overridden during opts parsing
      @config_file = File.expand_path("../../config/config.yml", __FILE__)
      parse_options!

      @config = Uhuru::RepositoryManager::Config.from_file(@config_file)
      ENV["RACK_ENV"] =  @config[:dev_mode] ? "development" : "production"

      @config[:bind_address] = VCAP.local_ip(@config[:local_route])

      create_pidfile
      setup_logging
      @config[:logger] = logger
    end

    # returns a logger object
    def logger
      $logger ||= Steno.logger("uhuru-repository-manager.runner")
    end

    def options_parser
      @parser ||= OptionParser.new do |opts|
        opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
          @config_file = opt
        end
      end
    end

    def parse_options!
      options_parser.parse! @argv
    rescue
      puts options_parser
      exit 1
    end

    # creates a pid file
    def create_pidfile
      begin
        pid_file = VCAP::PidFile.new(@config[:pid_filename])
        pid_file.unlink_at_exit
      rescue
        puts "ERROR: Can't create pid file #{@config[:pid_filename]}"
        exit 1
      end
    end

    # stops the logging
    def setup_logging
      steno_config = Steno::Config.to_config_hash(@config[:logging])
      steno_config[:context] = Steno::Context::ThreadLocal.new
      Steno.init(Steno::Config.new(steno_config))
    end

    # entry point for the WebUI service
    def run!
      $config = @config.dup

      require "configure_db"

      db = Uhuru::RepositoryManager::ConfigureDb.connect logger

      require 'main'

      # Only load main class after configurations are initialized and we're ready to run.
      webui = Uhuru::RepositoryManager::RepositoryManager.new

      # check if tables exists in db and create them if not
      # when problems are encountered stops the app
      table_creator = Uhuru::RepositoryManager::CreateTables.new db
      begin
        unless table_creator.exist_tables?
          table_creator.create_tables
        end

        master_mirror = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors(:name => 'Master').first

        if master_mirror
          Uhuru::RepositoryManager::Model::Mirrors.update(master_mirror,
                                                          {
                                                              :description => $config[:master_mirror][:description],
                                                              :hostname => $config[:master_mirror][:domain],
                                                              :status => $config[:master_mirror][:status]
                                                          })
        else
          Uhuru::RepositoryManager::Model::Mirrors.create('Master', $config[:master_mirror][:description], $config[:master_mirror][:domain], $config[:master_mirror][:status], "master")
        end
      rescue => e
        puts "ERROR: Database connection problems: #{e.message} - #{e.backtrace}"
        exit 1
      end

      # creates default admin user if doesn't exist
      # generates ssh keys and adds them in db
      # and adds it to password files
      begin
        master_mirror_user_sys = $config[:master_mirror][:blobstore_options][:user]
        administrator_email = $config[:repository_manager][:administrator_email]

        if Uhuru::RepositoryManager::Model::Users.get_users(:username => administrator_email).count == 0
          Uhuru::RepositoryManager::HtpasswdHandler.create_password(administrator_email, "admin")

          home_path = File.join($config[:path_home_user], master_mirror_user_sys)

          `test -d "#{home_path}" || ( mkdir -p #{home_path} ; chown #{master_mirror_user_sys}.#{master_mirror_user_sys} #{home_path} ; chmod 0700 #{home_path} )`

          admin_user = Uhuru::RepositoryManager::Model::Users.create(administrator_email, "Admin", "Account", "Uhuru Software", "urm administrator", "United States", "Redmond", nil, nil, true, master_mirror_user_sys)
          Uhuru::RepositoryManager::Model::Users.update(admin_user, {:active => true})
        end

        master_mirror_user_home_path = `cat /etc/passwd|grep -w ^#{master_mirror_user_sys}|cut -f 6 -d \:`
		    master_mirror_user_home_path = master_mirror_user_home_path.gsub("\n",'')

        public_key = `cat #{master_mirror_user_home_path}/.ssh/id_rsa.pub`
        unless public_key
          `sudo -u #{master_mirror_user_sys} test -e #{master_mirror_user_home_path}/.ssh/id_rsa || ssh-keygen -f #{master_mirror_user_home_path}/.ssh/id_rsa -N ''`
          public_key = `cat #{master_mirror_user_home_path}/.ssh/id_rsa.pub`
          `echo "#{public_key}" >>#{master_mirror_user_home_path}/.ssh/authorized_keys ; chmod 0600 #{master_mirror_user_home_path}/.ssh/authorized_keys ; chown #{master_mirror_user_sys}.#{master_mirror_user_sys} #{master_mirror_user_home_path}/.ssh/authorized_keys`
        end

        admin_user = Uhuru::RepositoryManager::Model::Users.get_users(:username => administrator_email).first
        if admin_user.access_keys.count == 0
          Uhuru::RepositoryManager::Model::AccessKeys.create(public_key, "admin local key", admin_user)
        end

      rescue => ex
        puts "ERROR: Unable to create default admin user. #{ex.message} #{ex.backtrace}"
      end

      # create ucc public and private groups if doesn't exist
      ucc_public = "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_public"
      ucc_private = "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_private"
      groups = `getent group #{ucc_public} #{ucc_private}`

      if !groups.include?(ucc_public)
        ucc_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], ucc_public)
        Uhuru::RepositoryManager::FilesystemHandler.add_group(ucc_public, ucc_path)
      end

      if !groups.include?(ucc_private)
        ucc_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], ucc_private)
        Uhuru::RepositoryManager::FilesystemHandler.add_group(ucc_private, ucc_path)
      end

      app = Rack::Builder.new do
        use Rack::CommonLogger

        map "/" do
          run webui
        end

      end

      @thin_server = Thin::Server.new('0.0.0.0', @config[:port], app)
      trap_signals

      @thin_server.threaded = true
      @thin_server.start!
    end

    # stopping the EventMachine and Thin when TERM and INT signals are received
    def trap_signals
      ["TERM", "INT"].each do |signal|
        trap(signal) do
          @thin_server.stop! if @thin_server
          EM.stop
        end
      end
    end
  end
end
