#
#    The access section for the urm
#

module Uhuru
  module RepositoryManager
    module Access
      def self.registered(urm)

        # this is the main accesses page, a list of accesses will be shown on the left side
        # the right side will NOT be populated with access details until an access is selected
        #
        urm.get ACCESS do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          users = Uhuru::RepositoryManager::Model::Users.get_users

          render_erb do
            template :'admin/access'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, nil
            var :access, nil
          end
        end

        # this page is an extension of the mirrors page above
        # in the right side of the page a form will be shown with a list of all products the selected user can access
        # each product in the list will have a changeable value that allows the user to access the product ( enable/disable will be the value of each product )
        #
        urm.get EDIT_ACCESS do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          users = Uhuru::RepositoryManager::Model::Users.get_users
          accesses = Uhuru::RepositoryManager::Model::Products.get_products
          user = params[:user]

          render_erb do
            template :'admin/access'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, user
            var :accesses, accesses
          end
        end


        # These are the post methods for the actions specified above
        #
        # CHANGE_ACCESS_STATE     - the post method for changing the user access to the selected product
        #
        urm.post CHANGE_ACCESS_STATE do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          users = Uhuru::RepositoryManager::Model::Users.get_users
          accesses = Uhuru::RepositoryManager::Model::Products.get_products

          user = params[:user_id]
          current_user = Uhuru::RepositoryManager::Model::Users.get_users(:id => params[:user_id])

          begin
            accesses.each do |access|
              selection = params[('access_state_' + access.id.to_s).to_sym]

              if selection == 'on' && current_user.first.products.find{|product| product.id == access.id} == nil
                current_access = Uhuru::RepositoryManager::Model::Products.get_products(:id => access.id)
                Uhuru::RepositoryManager::Model::Users.add_product_access(current_user.first, current_access.first)
              elsif selection == nil && current_user.first.products.find{|product| product.id == access.id}
                current_access = Uhuru::RepositoryManager::Model::Products.get_products(:id => access.id)
                Uhuru::RepositoryManager::Model::Users.remove_product_access(current_user.first, current_access.first)
              end
            end
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Change access exception: ', ex.message)
            $logger.error("Change access exception: #{ex.message} backtrace: #{ex.backtrace}")
          end

          render_erb do
            template :'admin/access'
            layout :'layouts/layout'
            var :users, users
            var :selected_user, user
            var :accesses, accesses
            var :error_message, error_message || nil
          end
        end
      end
    end
  end
end