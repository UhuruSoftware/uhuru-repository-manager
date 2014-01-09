#
#    The admin actions for the URM(products, users, mirrors ...)
#

module Uhuru
  module RepositoryManager
    module Admin
      def self.registered(urm)

        urm.get ADMIN_PRODUCTS do
          products = [ "product 1", "product2", "product 3"]
          erb :'admin/products', :layout => :'layouts/layout', :locals => { :products => products }
        end

        urm.get ADMIN_MIRRORS do
          mirrors = [ "mirror 1", "mirror 2", "mirror 3"]
          erb :'admin/mirrors', :layout => :'layouts/layout', :locals => { :mirrors => mirrors }
        end

        urm.get ADMIN_USERS do
          users = [ "user 1", "user 2", "user 3", "user 4", "user 5"]
          erb :'admin/users', :layout => :'layouts/layout', :locals => { :users => users }
        end

        urm.get ADMIN_ACCESS do
          users = [ "user 1", "user 2", "user 3", "user 4", "user 5"]
          erb :'admin/access', :layout => :'layouts/layout', :locals => { :users => users }
        end

      end
    end
  end
end