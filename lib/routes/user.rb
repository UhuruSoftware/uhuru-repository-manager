#
#    The user actions for the URM(about page, mirrors...)
#

module Uhuru
  module RepositoryManager
    module User
      def self.registered(urm)

        urm.get USER_HOWTO do
          erb :'user/howto', :layout => :'layouts/layout'
        end

        urm.get USER_MIRRORS do
          erb :'user/mirrors', :layout => :'layouts/layout'
        end

      end
    end
  end
end