#
#    The users section for the urm
#

module Uhuru
  module RepositoryManager
    module Users
      def self.registered(urm)

        # this is the main users page, a list of users will be shown on the left side
        # the right side will NOT be populated with user details until a user is selected
        #
        urm.get USERS do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          users = Uhuru::RepositoryManager::Model::Users.get_users

          render_erb do
            template :'admin/users'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, nil
          end
        end

        # this page is an extension of the users page above
        # in the right side of the page a form will be shown with the user properties for the user that is selected selected
        #
        urm.get EDIT_USER do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end

          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')
          users = Uhuru::RepositoryManager::Model::Users.get_users
          user = params[:user]

          render_erb do
            template :'admin/users'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, user
            var :countries, countries
          end
        end

        # this page is an extension of the users page above
        # in the right side of the page will be shown a blank form for adding a new user with blank fields by default
        #
        urm.get ADD_USER do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end

          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')
          users = Uhuru::RepositoryManager::Model::Users.get_users

          render_erb do
            template :'admin/users'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, nil
            var :countries, countries
            var :new_user, :new_user
          end
        end


        # These are the post methods for the actions specified above
        #
        # EDIT_USER     - the post method for update selected user
        # ADD_USER      - the post method for adding a new user
        # DELETE_USER   - the post method for removing a user from the list
        #
        urm.post EDIT_USER do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end

          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')
          # we can mock the password with a key, in the update user the password is not necessary
          validated_user_data = Uhuru::RepositoryManager::Users.validate_user_data(params[:username], params[:first_name], params[:last_name], password = :password, confirm_password = :password, params[:organization], params[:job_title])

          user = Uhuru::RepositoryManager::Model::Users.get_users(:id => params[:user])
          hash = {
                    :username => params[:username],
                    :first_name => params[:first_name],
                    :last_name => params[:last_name],
                    :job_title => params[:job_title],
                    :organization => params[:organization],
                    :active => params[:is_active] == 'on' ? true : false,
                    :admin => params[:is_admin] == 'on' ? true : false,
                    :city => params[:city],
                    :address => params[:address],
                    :phone => params[:phone]
          }

          if validated_user_data == true
            Uhuru::RepositoryManager::Model::Users.update(user.first, hash)
          else
            begin
              raise validated_user_data
            rescue Exception => ex
              error_message = Uhuru::RepositoryManager::Error.new('Edit user: ', ex.message)
              $logger.error("Edit user : #{ex.message} - #{ex.backtrace}")
            end
          end

          users = Uhuru::RepositoryManager::Model::Users.get_users
          render_erb do
            template :'admin/users'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, user.first.id
            var :countries, countries
            var :error_message, error_message || nil
          end
        end

        urm.post ADD_USER do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end

          countries_file = File.expand_path("../../../config/countries.txt", __FILE__)
          countries = File.open(countries_file, "rb").read.split(';')
          validated_user_data = Uhuru::RepositoryManager::Users.validate_user_data(params[:username], params[:first_name], params[:last_name], params[:password], params[:confirm_password], params[:organization], params[:job_title])
          user_exists = Uhuru::RepositoryManager::Model::Users.get_users(:username => params[:username]) != [] ? true : false

          if validated_user_data == true && user_exists == false
            Uhuru::RepositoryManager::Model::Users.create(params[:username], params[:first_name], params[:last_name], params[:organization], params[:job_title], params[:country], params[:city], params[:address], params[:phone], params[:admin])
            Uhuru::RepositoryManager::HtpasswdHandler.create_password(params[:username], params[:password])
          else
            begin
              if user_exists
                raise Uhuru::RepositoryManager::Error.new('Signup error', 'The user already exists, try a different account name.')
              else
                raise validated_user_data
              end
            rescue Exception => ex
              error_message = Uhuru::RepositoryManager::Error.new('Add user: ', ex.message)
              $logger.error("Add user : #{ex.message} - #{ex.backtrace}")
            end
          end

          users = Uhuru::RepositoryManager::Model::Users.get_users
          render_erb do
            template :'admin/users'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, nil
            var :error_message, error_message || nil
            var :countries, countries
            var :new_user, :new_user
          end
        end

        # this method does not need to have error handling
        #
        urm.post DELETE_USER do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          user = Uhuru::RepositoryManager::Model::Users.get_users(:id => params[:user])
          Uhuru::RepositoryManager::Model::Users.delete(user.first)

          redirect USERS
        end
      end

      # Data validation for user (this method is used in edit user and add user routes)
      #
      def self.validate_user_data(username, first_name, last_name, password, confirm_password, organization, job_title)
        # check if the email address is valid
        unless /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/.match(username)
          return Uhuru::RepositoryManager::Error.new('Signup error', 'Please enter a valid email address.')
        end
        # sanitize the first and last name, pop error if one of them are nill
        unless /[a-zA-Z\-'\s]+/.match(first_name) && /[a-zA-Z\-'\s]+/.match(last_name)
          return Uhuru::RepositoryManager::Error.new('Signup error', 'Please type a valid first name and last name.')
        end

        if password != confirm_password
          return Uhuru::RepositoryManager::Error.new('Signup error', 'User password and confirm password does not match.')
        elsif password == nil || password == ''
          return Uhuru::RepositoryManager::Error.new('Signup error', 'User password can not be blank.')
        elsif !password_length(password)
          return Uhuru::RepositoryManager::Error.new('Signup error', "User password needs to be between #{PASSWORD_MINIMUM_LENGTH} and #{PASSWORD_MAXIMUM_LENGTH} characters.")
        elsif organization == ''
          return Uhuru::RepositoryManager::Error.new('Signup error', 'Organization can not be blank.')
        elsif job_title == ''
          return Uhuru::RepositoryManager::Error.new('Signup error', 'Job title can not be blank.')
        end

        return true
      end
    end
  end
end