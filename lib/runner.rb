require 'main'
require 'steno'
require 'config'
require 'thin'
require 'rack_dav'
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
      EM.run do
        $config = @config.dup

        # Only load the Web UI after configurations are initialized and we're ready to run.
        webui = Uhuru::RepositoryManager::RepositoryManager.new

        app = Rack::Builder.new do
          use Rack::CommonLogger

          map "/" do
            run webui
          end

          map "/templates" do
            use Rack::Auth::Basic do |username, password|
              user_login = UsersSetup.new($config)
              user = user_login.login(username, password)

              user.is_a?(RuntimeError) ? false : user.is_admin
            end

            run RackDAV::Handler.new(:root => $config[:template_apps_dir])
          end
        end

        @thin_server = Thin::Server.new(@config[:bind_address], @config[:port], app)
        trap_signals

        @thin_server.threaded = true
        @thin_server.start!
      end
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
