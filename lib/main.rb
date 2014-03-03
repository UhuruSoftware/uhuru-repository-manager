#
#    The main class for the URM(Uhuru Repository Manager)
#    This file will include all the necessary libraries abd routes,
#    also will set the file system inside the project and have the index page route
#

require 'rubygems'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/session'
require 'blobstore_client'
require 'yaml'
require 'securerandom'
require 'fileutils'
require 'rack/recaptcha'

require '../lib/routes/route_base'
require '../lib/routes/guest'
require '../lib/routes/user'
require '../lib/routes/admin'

require '../lib/routes/products'
require '../lib/routes/versions'
require '../lib/routes/mirrors'
require '../lib/routes/users'
require '../lib/routes/access'

require "create_tables"
require "filesystem_handler"
require "model/mirrors"
require "model/products"
require "model/versions"
require "model/users"
require "model/dependencies"
require "model/access_keys"
require "model/user_tokens"
require "client"
require "email"
require "base64"
require 'encryption_decryption'
require "manifest_generator"
require "htpasswd_handler"
require "logger"

module Uhuru::RepositoryManager
  class RepositoryManager < Sinatra::Base

    ENV_COPY  = %w[ REQUEST_METHOD HTTP_COOKIE rack.request.cookie_string
                rack.session rack.session.options rack.input SERVER_SOFTWARE SERVER_NAME
                rack.version rack.errors rack.multithread rack.run_once SERVER_PORT SERVER_PROTOCOL
                rack.url_scheme REMOTE_ADDR sinatra.commaonlogger rack.logger ]

    set :root, File.expand_path("../../", __FILE__)
    set :views, File.expand_path("../../views", __FILE__)
    set :public_folder, File.expand_path("../../public", __FILE__)
    helpers Rack::Recaptcha::Helpers
    use Rack::Session::Pool
    use Rack::Recaptcha, :public_key => $config[:recaptcha][:recaptcha_public_key], :private_key => $config[:recaptcha][:recaptcha_private_key]
    #set :raise_errors, false
    #set :dump_errors, false
    set :show_exceptions, false
    #set :environment, :production

    register Uhuru::RepositoryManager::Guest
    register Uhuru::RepositoryManager::User
    register Uhuru::RepositoryManager::Admin

    register Uhuru::RepositoryManager::Products
    register Uhuru::RepositoryManager::Versions
    register Uhuru::RepositoryManager::Mirrors
    register Uhuru::RepositoryManager::Users
    register Uhuru::RepositoryManager::Access

    $logger = Logger.new($config[:logging][:file])
    $logger.level = Logger::WARN

    get INDEX do
      render_erb do
        template :'guest/index'
        layout :'layouts/layout'
      end
    end

    # dynamic endpoint used by ucc to generate a user's products manifest containing available products and writes it
    # in the home user directory
    get GET_PRODUCTS_MANIFEST do
      if request.ip == "127.0.0.1"
        begin
          user_sys = params[:user_sys]
          user_products = File.join($config[:path_home_user], user_sys, 'products.yml')

          user = Uhuru::RepositoryManager::Model::Users.get_users(:user_sys => user_sys).first
          File.open(user_products, "w") do |file|
            file.write(Uhuru::RepositoryManager::ManifestGenerator.generate_products_yml(user))
          end

          # changes products.yml file permissions to readonly (0400)
          File.chmod(0400, user_products)

          # changes products.yml file ownership to username.root
          `chown #{user_sys}.root #{user_products}`
        rescue => ex
          $logger.error("Get products manifest for user: #{user_sys}. ERROR: #{ex.message} - #{ex.backtrace}")
        end
      end
    end

    # dynamic endpoint used by ucc to generate a user's product manifest containing available versions and writes it
    # in the home user directory
    get GET_PRODUCT_MANIFEST do
      if request.ip == "127.0.0.1"
        begin
          product_name = params[:product_name]
          user_sys = params[:user_sys]
          user_product = File.join($config[:path_home_user], user_sys, "#{product_name}_manifest.yml")

          product_obj = Uhuru::RepositoryManager::Model::Products.get_products(:name => product_name).first

          if !product_obj.nil?
            File.open(user_product, "w") do |file|
              file.write(Uhuru::RepositoryManager::ManifestGenerator.generate_manifest_yml(product_obj, true))
            end

            # changes manifest.yml file permissions to readonly (0400)
            File.chmod(0400, user_product)

            # changes manifest.yml file ownership to username.root
            `chown #{user_sys}.root #{user_product}`
          else
            $logger.error("Product: #{product_name} does not exist. User: #{user_sys} made the request.")
          end
        rescue => ex
          $logger.error("Get product: #{product_name} manifest for user: #{user_sys}. ERROR: #{ex.message} - #{ex.backtrace}")
        end
      end
    end

    # these two routes redirect the user to the login page with the distinct error
    #
    get NOT_LOGGED_IN do
      error_message = Uhuru::RepositoryManager::Error.new('Not logged in', 'Please login in order to continue.')
      render_erb do
        template :'guest/index'
        layout :'layouts/layout'
        var :error_message, error_message
      end
    end

    get NOT_ADMIN do
      error_message = Uhuru::RepositoryManager::Error.new('Not an admin user', 'Please login as an admin in order to continue.')
      render_erb do
        template :'guest/index'
        layout :'layouts/layout'
        var :error_message, error_message
      end
    end

    # return the css files
    get '/css_layout' do
      send_file "../public/css/layout.css"
    end

    get '/css_views' do
      send_file "../public/css/views.css"
    end

    # main error pages ( 404 not found error, 500 server error )
    not_found do
      render_erb do
        template :'error/not_found'
        layout :'layouts/layout'
      end
    end

    error do
      $logger.error("Server error: #{request.env['sinatra.error'].message} - #{request.env['sinatra.error'].backtrace}")
      error = "Sorry, a server error has occurred. Please contact your system administrator.<br /><br />#{request.env['sinatra.error'].message}"

      render_erb do
        template :'error/server_error'
        layout :'layouts/layout'
        var :error, error
      end
    end

    def render_erb(&code)
      template, layout, locals = ErbRenderHelper.new.render &code

      erb template,
          :layout => layout,
          :locals => locals
    end

    # these two method will return true or false, based on the response from each route an action will be taken
    #
    def logged_in?
      if session[:username]
        if session[:logged_in?]
          return true
        end
      else
        return false
      end
    end

    def logged_in_as_admin?
      if session[:username] != nil
        if session[:logged_in?] && session[:is_admin?]
          return true
        end
      else
        return false
      end
    end
  end

  # class design for creating custom error objects
  #
  class Error < RuntimeError
    attr_accessor :title, :message

    def initialize(title, message)
      @title = title
      @message = message
    end
  end

  # class design to render the erb files along with the variables
  #
  class ErbRenderHelper
    # render the layout erb
    def layout(set_layout)
      @layout = set_layout
    end

    # render the erb required
    def template(set_template)
      @template = set_template
    end

    # return the values of variables
    #
    def var(name, value)
      @locals[name] = value
    end

    def render(&code)
      @layout = nil
      @template = nil
      @locals = { }

      self.instance_eval &code

      unless @layout
        @layout = @template
      end

      [@template, @layout, @locals]
    end
  end
end