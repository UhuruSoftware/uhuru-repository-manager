#
#    The user actions for the URM(about page, mirrors...)
#

module Uhuru
  module RepositoryManager
    module User
      def self.registered(urm)
        # the routes that redirect to the user pages (the how-to page where a small tutorial will be shown and the dashboard page)
        #
        urm.get USER_DASHBOARD do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end

          mirrors = Uhuru::RepositoryManager::Model::Mirrors.get_dashboard_mirrors
          user_sys = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first.user_sys
          home_user = File.join($config[:path_home_user], user_sys)

          render_erb do
            template :'dashboard'
            layout :'layouts/layout'
            var :mirrors, mirrors
            var :user_sys, user_sys
            var :home_user, home_user
          end
        end

        urm.get USER_HOWTO do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end

          render_erb do
            template :'user/howto'
            layout :'layouts/layout'
          end
        end

        urm.get USER_KEYS do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end

          user_id = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first.id
          access_keys = Uhuru::RepositoryManager::Model::AccessKeys.get_access_keys_by_user(user_id)
          render_erb do
            template :'keys'
            layout :'layouts/layout'
            var :access_keys, access_keys
          end
        end

        urm.get USER_ACCOUNT_SETTINGS do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end

          user = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first
          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')

          render_erb do
            template :'account_settings'
            layout :'layouts/layout'
            var :user, user
            var :countries, countries
          end
        end

        # Add and remove access keys for the logged in user
        #
        urm.post USER_ADD_KEY do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end
          user = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first

          begin
            Uhuru::RepositoryManager::Model::AccessKeys.create(params[:key].gsub("\n",''), params[:name], user)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Access key error: ', ex.message)
            $logger.error("Add access key : #{ex.message} - #{ex.backtrace}")
          end

          access_keys = Uhuru::RepositoryManager::Model::AccessKeys.get_access_keys_by_user(user.id)
          render_erb do
            template :'keys'
            layout :'layouts/layout'
            var :access_keys, access_keys
            var :error_message, error_message || nil
          end
        end

        urm.post USER_DELETE_KEY do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end
          user_id = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first.id

          begin
            key = Uhuru::RepositoryManager::Model::AccessKeys.get_access_keys_by_user(user_id).find{|key| key.value == params[:key]}
            Uhuru::RepositoryManager::Model::AccessKeys.delete(key)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Access key error: ', ex.message)
            $logger.error("Delete access key : #{ex.message} - #{ex.backtrace}")
          end

          access_keys = Uhuru::RepositoryManager::Model::AccessKeys.get_access_keys_by_user(user_id)
          render_erb do
            template :'keys'
            layout :'layouts/layout'
            var :access_keys, access_keys
            var :error_message, error_message || nil
          end
        end

        # Post method for changing the user data and metadata(the user that is currently logged in)
        #
        urm.post USER_ACCOUNT_SETTINGS do
          unless logged_in?
            redirect NOT_LOGGED_IN
          end

          user = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first
          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')

          hash = {
              :first_name => params[:first_name],
              :last_name => params[:last_name],
              :organization => params[:organization],
              :job_title => params[:job_title],
              :country => params[:country],
              :city => params[:city],
              :address => params[:address],
              :phone => params[:phone]
          }

          begin
            # sanitize the first and last name, pop error if one of them are nill
            unless /[a-zA-Z\-'\s]+/.match(params[:first_name]) && /[a-zA-Z\-'\s]+/.match(params[:last_name])
              raise Uhuru::RepositoryManager::Error.new('Account settings error', 'Please type a valid first name and last name.')
            end

            if params[:organization] == ''
              raise Uhuru::RepositoryManager::Error.new('Account settings error', 'Organization can not be blank.')
            elsif params[:job_title] == ''
              raise Uhuru::RepositoryManager::Error.new('Account settings error', 'Job title can not be blank.')
            end

            Uhuru::RepositoryManager::Model::Users.update(user, hash)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Change account data: ', ex.message)
            $logger.error("Change account data : #{ex.message} - #{ex.backtrace}")
          end

          begin
            if params[:password] != params[:confirm_password]
              raise Uhuru::RepositoryManager::Error.new('Change password', 'Your password does not match with the confirm password.')
            else
              if password_length(params[:password])
                Uhuru::RepositoryManager::HtpasswdHandler.create_password(session[:username], params[:password])
              else
                raise Uhuru::RepositoryManager::Error.new('Change password', "User password needs to be between #{PASSWORD_MINIMUM_LENGTH} and #{PASSWORD_MAXIMUM_LENGTH} characters.")
              end
            end

          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Change account data: ', ex.message)
            $logger.error("Change account data : #{ex.message} - #{ex.backtrace}")
          end

          render_erb do
            template :'account_settings'
            layout :'layouts/layout'
            var :user, user
            var :countries, countries
            var :error_message, error_message || nil
          end
        end
      end
    end
  end
end