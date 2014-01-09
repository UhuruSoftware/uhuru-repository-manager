#
#    All other types of routes that are not user specific
#

module Uhuru
  module RepositoryManager
    module Core
      def self.registered(urm)

        urm.get '/poll' do
          erb :'guest/login', :layout => :'layouts/layout'
        end

      end
    end
  end
end