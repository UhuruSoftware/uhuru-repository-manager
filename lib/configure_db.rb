require 'sequel'
require 'yaml'

module Uhuru::RepositoryManager
  # class that will returns a sequel database connection loaded from config file
  class ConfigureDb
    def self.connect(logger)
      opts = $config[:db]

      connection_options = {}
      [:max_connections, :pool_timeout].each do |key|
        connection_options[key] = opts[key] if opts[key]
      end

      db = Sequel.connect(opts[:database], connection_options)
      db.logger = logger
      db.sql_log_level = opts[:log_level] || :debug2

      db
    end
  end
end