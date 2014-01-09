#
#    The guest actions for the URM(login, register, logout)
#

module Uhuru
  module RepositoryManager
    module Guest
      def self.registered(urm)

        urm.get LOGIN do
          erb :'guest/login', :layout => :'layouts/layout'
        end

        urm.get SIGNUP do
          erb :'guest/login', :layout => :'layouts/layout'
        end

        urm.get LOGOUT do
          erb :'guest/login', :layout => :'layouts/layout'
        end

      end
    end
  end
end