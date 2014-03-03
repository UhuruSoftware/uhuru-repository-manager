#
#    The mirrors section for the urm
#

module Uhuru
  module RepositoryManager
    module Mirrors
      def self.registered(urm)

        # this is the main mirrors page, a list of mirrors will be shown on the left side
        # the right side will NOT be populated with mirror details until a user selects a mirror
        #
        urm.get MIRRORS do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          mirrors = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors

          render_erb do
            template :'admin/mirrors'
            layout :'layouts/layout'
            var :mirrors, mirrors
            var :selected_mirror, nil
          end
        end

        # this page is an extension of the mirrors page above
        # in the right side of the page a form will be shown with the mirror properties for the mirror that is selected selected
        #
        urm.get EDIT_MIRROR do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          mirrors = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors
          mirror = params[:mirror]

          render_erb do
            template :'admin/mirrors'
            layout :'layouts/layout'
            var :mirrors, mirrors
            var :selected_mirror, mirror
          end
        end

        # this page is an extension of the mirrors page above
        # in the right side of the page will be shown a blank form for adding a new mirror with blank fields by default
        #
        urm.get ADD_MIRROR do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          mirrors = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors

          render_erb do
            template :'admin/mirrors'
            layout :'layouts/layout'
            var :mirrors, mirrors
            var :selected_mirror, nil
            var :new_mirror, :new_mirror
          end
        end


        # These are the post methods for the actions specified above
        #
        # EDIT_MIRROR     - the post method for update selected mirror
        # ADD_MIRROR      - the post method for adding a new mirror
        # DELETE_MIRROR   - the post method for removing a mirror from the list
        #
        urm.post EDIT_MIRROR do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          mirror = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors.find{|mirror| mirror.name.to_s == params[:mirror]}

          hash = {
                    :name => params[:mirror_name],
                    :endpoint => params[:hostname],
                    :user => params[:user],
                    :status => params[:status] == 'true' ? true : false,
                    :description => params[:description]
                 }

          begin
            Uhuru::RepositoryManager::Model::Mirrors.update(mirror, hash)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Edit mirror: ', ex.message)
            $logger.error("Edit mirror : #{ex.message} - #{ex.backtrace}")
          end

          mirrors = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors
          render_erb do
            template :'admin/mirrors'
            layout :'layouts/layout'
            var :mirrors, mirrors
            var :selected_mirror, mirror.id
            var :error_message, error_message || nil
          end
        end

        urm.post ADD_MIRROR do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          begin
            Uhuru::RepositoryManager::Model::Mirrors.create(params[:mirror_name], params[:description], params[:hostname], params[:status] == 'true' ? true : false)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Add mirror: ', ex.message)
            $logger.error("Add mirror :#{ex.message} - #{ex.backtrace}")
          end

          mirrors = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors
          render_erb do
            template :'admin/mirrors'
            layout :'layouts/layout'
            var :mirrors, mirrors
            var :selected_mirror, nil
            var :error_message, error_message || nil
            var :new_mirror, :new_mirror
          end
        end

        # this method does not need to have error handling
        #
        urm.post DELETE_MIRROR do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          mirror = Uhuru::RepositoryManager::Model::Mirrors.get_mirrors(:id => params[:mirror])
          Uhuru::RepositoryManager::Model::Mirrors.delete(mirror.first)

          redirect MIRRORS
        end

      end
    end
  end
end