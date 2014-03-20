#
#    The guest actions for the URM(login, register, logout)
#

module Uhuru
  module RepositoryManager
    module Guest
      def self.registered(urm)
        urm.get SIGNUP do
          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')

          render_erb do
            template :'guest/signup'
            layout :'layouts/layout'
            var :countries, countries
          end
        end

        urm.get FORGOT_PASSWORD do
          render_erb do
            template :'guest/forgot_password'
            layout :'layouts/layout'
          end
        end

        urm.get EMAIL_SENT do
          render_erb do
            template :'guest/email_sent'
            layout :'layouts/layout'
          end
        end

        urm.get PASSWORD_RESET do
          begin
            token = params[:token]
            user_token = Uhuru::RepositoryManager::Model::UserTokens.get_token(token).first

            expire_in_hours = $config[:repository_manager][:reset_password_expiration_hours]
            expiration_max = Time.now + (60 * 60 * expire_in_hours)

            if user_token and user_token.expiration_date < expiration_max
              username = user_token.user.username

              generated_password = (0...8).map { (65 + rand(26)).chr }.join
              Uhuru::RepositoryManager::HtpasswdHandler.create_password(username, generated_password)

              administrator_email = $config[:repository_manager][:administrator_email]
              first_name = user_token.user.first_name
              domain = $config[:repository_manager][:domain]
              email_body =  ERB.new($config[:repository_manager][:password_reset_email]).result(binding)
              Email.send_email(user_token.user.username, 'Your new password', email_body)

              render_erb do
                template :'guest/message'
                layout :'layouts/layout'
                var :message, "Password reset successful."
                var :details, "A new password has been generated and mailed to you at #{user_token.user.username}."
              end
            end
          rescue => e
            $logger.error("Password reset: #{e.message} - #{e.backtrace}")

            render_erb do
              template :'guest/message'
              layout :'layouts/layout'
              var :message, "There was an error while trying to reset your password."
              var :details, "Please contact the administrator at #{$config[:repository_manager][:administrator_email]}."
            end
          end
        end

        urm.post LOGIN do
          begin
            credentials_ok = Uhuru::RepositoryManager::HtpasswdHandler.valid_password?(params[:username], params[:password])
            user =nil

            if credentials_ok
              user = Uhuru::RepositoryManager::Model::Users.get_users(:username => params[:username]).first
            end

            if credentials_ok and user and user.active
              session[:username] = params[:username]
              is_admin = session[:is_admin?] = user.admin
              session[:logged_in?] = true

              if is_admin
                redirect DASHBOARD
              else
                redirect USER_DASHBOARD
              end
            else
              raise Uhuru::RepositoryManager::Error.new('Login error', 'The username or password is incorrect. Please try again.')
            end
          rescue => e
            $logger.warn("Login error exception: #{e.message} - #{e.backtrace}")
            render_erb do
              template :'guest/index'
              layout :'layouts/layout'
              var :error_message, e
            end
          end
        end

        urm.post SIGNUP do
          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')

          email = params[:username]
          first_name = params[:first_name]
          last_name = params[:last_name]
          job_title = params[:job_title]
          organization = params[:organization]
          country = params[:country]
          city = params[:city]
          address = params[:address]
          phone = params[:phone]

          begin
            if $config[:recaptcha][:use_recaptcha] == true || $config[:recaptcha][:use_recaptcha] == 'true'
              unless recaptcha_valid?
                raise Uhuru::RepositoryManager::Error.new('Signup error', 'Recaptcha code is invalid. Try again.')
              end
            end

            # check if the email address is valid
            unless /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/.match(email)
              raise Uhuru::RepositoryManager::Error.new('Signup error', 'Please enter a valid email address.')
            end
            # sanitize the first and last name, pop error if one of them are nill
            unless /[a-zA-Z\-'\s]+/.match(first_name) && /[a-zA-Z\-'\s]+/.match(last_name)
              raise Uhuru::RepositoryManager::Error.new('Signup error', 'Please type a valid first name and last name.')
            end

            if params[:password] != params[:confirm_password]
              raise Uhuru::RepositoryManager::Error.new('Signup error', 'Your password and confirm password does not match.')
            elsif params[:password] == nil || params[:password] == ''
              raise Uhuru::RepositoryManager::Error.new('Signup error', 'Your password can not be blank.')
            elsif !password_length(params[:password])
              raise Uhuru::RepositoryManager::Error.new('Signup error', "User password needs to be between #{PASSWORD_MINIMUM_LENGTH} and #{PASSWORD_MAXIMUM_LENGTH} characters.")
            elsif Uhuru::RepositoryManager::Model::Users.get_users(:username => email) != []
              raise Uhuru::RepositoryManager::Error.new('Signup error', 'The user already exists, try a different account name.')
            elsif organization == ''
              raise Uhuru::RepositoryManager::Error.new('Signup error', 'Organization can not be blank.')
            end

            user = Uhuru::RepositoryManager::Model::Users.create(email, first_name, last_name, organization, job_title, country, city, address, phone, nil)
            Uhuru::RepositoryManager::HtpasswdHandler.create_password(email, params[:password])

            expire_in_days = $config[:repository_manager][:activation_link_expiration_days]
            signup_token = Uhuru::RepositoryManager::Model::UserTokens.create(user, Time.now + (60 *60 *24 * expire_in_days), 'registration')

            activation_link = "http://#{$config[:repository_manager][:domain]}/activate/#{signup_token.token}"
            first_name = user.first_name
            domain = $config[:repository_manager][:domain]
            email_body =  ERB.new($config[:repository_manager][:activation_email]).result(binding)

            Email.send_email(user.username, 'User account activation', email_body)
            render_erb do
              template :'guest/message'
              layout :'layouts/layout'
              var :message, "Thank you for signing up."
              var :details, "An activation e-mail has been sent.<br/>Click <a href='/'>here</a> to go back to the main page."
            end
          rescue => e
            $logger.warn("Signup error exception: #{e.message} - #{e.backtrace}" )
            render_erb do
              template :'guest/signup'
              layout :'layouts/layout'
              var :email, email
              var :first_name, first_name
              var :last_name, last_name
              var :job_title, job_title
              var :organization, organization
              var :selected_country, country
              var :city, city
              var :address, address
              var :phone, phone

              var :countries, countries
              var :error_message, e
            end
          end
        end

        urm.get ACTIVATE do
          token = params[:token]
          user_token = Uhuru::RepositoryManager::Model::UserTokens.get_token(token).first

          expire_in_days = $config[:repository_manager][:activation_link_expiration_days]
          expiration_max = Time.now + (60 *60 *24 * expire_in_days)

          if user_token and user_token.expiration_date < expiration_max
            # activate user
            Uhuru::RepositoryManager::Model::Users.update(user_token.user, {:active => true})

            # delete token
            Uhuru::RepositoryManager::Model::UserTokens.delete(user_token)

            render_erb do
              template :'guest/message'
              layout :'layouts/layout'
              var :message, "Activation successful."
              var :details, "You can now login <a href='/'>here</a>."
            end
          else
            Uhuru::RepositoryManager::Model::UserTokens.delete(user_token) if user_token

            render_erb do
              template :'guest/message'
              layout :'layouts/layout'
              var :message, "Activation failed."
              var :details, "If you think this message is in error, please send and e-mail to #{$config[:repository_manager][:administrator_email]}."
            end
          end
        end

        urm.post FORGOT_PASSWORD do
          username = params[:username]

          begin
            if /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i.match(username)
              user = Uhuru::RepositoryManager::Model::Users.get_users(:username => username).first

              if user
                expire_in_hours = $config[:repository_manager][:reset_password_expiration_hours]
                signup_token = Uhuru::RepositoryManager::Model::UserTokens.create(user, Time.now + (60 * 60 * expire_in_hours), 'registration')

                administrator_email = $config[:repository_manager][:administrator_email]
                reset_link = "http://#{$config[:repository_manager][:domain]}/password_reset/#{signup_token.token}"
                first_name = user.first_name
                domain = $config[:repository_manager][:domain]
                email_body =  ERB.new($config[:repository_manager][:password_recovery_email]).result(binding)

                Email.send_email(
                    params[:username],
                    'Password recovery',
                    email_body)
              else
                raise Uhuru::RepositoryManager::Error.new("Email error.", "We don't have a record for this e-mail address.")
              end
            else
              raise Uhuru::RepositoryManager::Error.new('Email error', 'Please enter a valid email address.')
            end

            render_erb do
              template :'guest/message'
              layout :'layouts/layout'
              var :message, "A recovery e-mail has been sent to this address."
              var :details, "Click <a href='/'>here</a> to go back to the main page."
            end
          rescue => e
            $logger.error("Forgot password: #{e.message} - #{e.backtrace}")
            render_erb do
              template :'guest/forgot_password'
              layout :'layouts/layout'
              var :error_message, e
            end
          end
        end

        urm.get LOGOUT do
          session[:username] = nil
          session[:is_admin?] = nil
          session[:logged_in?] = nil
          redirect INDEX
        end

      end
    end
  end
end