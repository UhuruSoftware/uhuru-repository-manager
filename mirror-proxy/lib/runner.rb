require "thin"
require 'vcap/common'
require 'vcap/config'
require 'config'
require 'optparse'

module Uhuru::MirrorProxy

  class Runner
    def initialize(argv)
      @argv = argv
      @config_file = File.expand_path("../../config/config.yml", __FILE__)
      parse_options!
      @config = Uhuru::MirrorProxy::Config.from_file(@config_file)
    end

    def create_pidfile
      begin
        pid_file = VCAP::PidFile.new(@config[:pid_filename])
        pid_file.unlink_at_exit
      rescue
        puts "ERROR: Can't create pid file #{@config[:pid_filename]}"
        exit 1
      end
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

    def run!
      $config = @config.dup
      app = Rack::Builder.new do
      require 'main'
        map "/" do
          run MirrorProxy::Main.new()
        end
      end
      @thin_server = Thin::Server.new("127.0.0.1", @config[:port])
      @thin_server.app = app

      trap_signals

      @thin_server.threaded = true
      @thin_server.start!
    end

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