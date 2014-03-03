#
#    The products and versions section for the urm
#

module Uhuru
  module RepositoryManager
    module Versions
      def self.registered(urm)

        # this is the main versions page, a list of versions will be shown on the left side
        # the right side will NOT be populated until the user selects a version
        #
        urm.get VERSIONS do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          product = params[:product]
          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, product
            var :selected_version, nil
          end
        end

        # this page is an extension of the versions page above
        # in the right side of the page a form will be shown with the version properties for the version that the user selected
        #
        urm.get EDIT_VERSION do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          product = params[:product]
          version = params[:version]
          version_obj = versions.find{|version| version.id.to_s == params[:version]}

          # Make a list of products from the dependencies list (read all the dependencies and make a list of their products in order to generate a selection box)
          #
          dependency_products = []
          all_dependencies = Uhuru::RepositoryManager::Model::Versions.get_available_dependencies(params[:product], version_obj)
          all_dependencies.each do |dependency|
            dependency_products << dependency.product if dependency.product.type != "ucc" && !dependency_products.include?(dependency.product)
          end

          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, product
            var :selected_version, version
            # we dont need a dependency list, so its safe to pass an empty array for this page (no product is yet selected)
            var :dependencies, []
            var :dependency_products, dependency_products
          end
        end

        # This route is used only for the selection of a particular product inside de dependency tab
        #
        urm.get REFRESH_DEPENDENCIES do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          # all the variables are the same as in edit version
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          product = params[:product]
          version = params[:version]
          selected_product_id = params[:selected_product]
          version_obj = versions.find{|version| version.id.to_s == params[:version]}

          # this will be the dependency list only for the selected product
          dependencies  = Uhuru::RepositoryManager::Model::Versions.get_available_dependencies(params[:product], version_obj).find_all{|d| d.product_id.to_s == selected_product_id}
          # this is a list of all dependencies like in the edit version route (all dependencies regardless for the selected product)
          all_dependencies = Uhuru::RepositoryManager::Model::Versions.get_available_dependencies(params[:product], version_obj)

          # Make a list of products from the dependencies list (read all the dependencies and make a list of their products in order to generate a selection box)
          #
          dependency_products = []
          all_dependencies.each do |dependency|
            dependency_products << dependency.product if dependency.product.type != "ucc" && !dependency_products.include?(dependency.product)
          end

          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, product
            var :selected_version, version
            # the dependency list only for the selected product
            var :dependencies, dependencies
            var :dependency_products, dependency_products
            # a variable that will keep the current tab selected, and auto-select the product in the select product
            var :selected_dependency_product_id, selected_product_id
          end
        end

        # this page is an extension of the versions page above
        # in the right side of the page a form will be shown with blank fields, this form is for adding a new version for the current product
        #
        urm.get ADD_VERSION do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          product = params[:product]
          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, product
            var :selected_version, nil
            var :new_version, :new_version
          end
        end

        # These are the post methods for the actions specified above
        #
        # EDIT_VERSION        - the post method for update selected version
        # ADD_VERSION         - the post method for adding a new version
        # DELETE_VERSION      - the post method for removing a version from the list
        # UPLOAD_VERSION_FILE - the post method that uploads the version file the user selects from his local hdd,
        #                       the file is uploaded and the form will become active. The version file will be removed after the user submits the form
        urm.post EDIT_VERSION do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          selected_product = params[:product]
          selected_version = params[:version]
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          version = versions.find{|version| version.id.to_s == params[:version]}

          hash = {
              :name => params[:version_name],
              :type => params[:type],
              :stable => params[:stable] == 'on' ? true : false,
              :public => params[:public] == 'on' ? true : false,
              :release_date => params[:release_date],
              :description => params[:description]
          }

          begin
            Uhuru::RepositoryManager::Model::Versions.update(version, hash)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Edit version: ', ex.message)
            $logger.error("Edit version : #{ex.message} - #{ex.backtrace}")
          end

          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          available_versions = Uhuru::RepositoryManager::Model::Versions.get_available_dependencies(params[:product], version)
          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, selected_product
            var :selected_version, selected_version
            var :error_message, error_message || nil
            var :available_versions, available_versions
            var :dependencies, []
            var :dependency_products, []
          end
        end

        urm.post ADD_VERSION do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          product = Uhuru::RepositoryManager::Model::Products.get_products.find{|product| product.id.to_s == params[:product]}
          selected_product = params[:product]
          user_sys = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first.user_sys
          path = File.join($config[:master_mirror][:blobstore_options][:tmp_local_directory], user_sys, session[:version_file_name])

          begin
            if params[:version_name].each_byte.find{|byte| byte == 32} != nil
              raise Uhuru::RepositoryManager::Error.new('Add product error', 'The version name can not have white spaces.')
            end

            session[:upload_state_blob_id] = Uhuru::RepositoryManager::Model::Versions.create(product.id, params[:version_name], params[:type], params[:description], path)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Add version: ', ex.message)
            $logger.error("Add version : #{ex.message} - #{ex.backtrace}")
          end

          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => product.id)
          products = Uhuru::RepositoryManager::Model::Products.get_products
          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, selected_product
            var :selected_version, nil
            var :error_message, error_message || nil
            var :new_version, :new_version
          end
        end

        urm.post ADD_VERSION_VIA_SFTP do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end

          product = Uhuru::RepositoryManager::Model::Products.get_products.find{|product| product.id.to_s == params[:product]}
          selected_product = params[:product]
          path = params[:server_path]

          begin
            if params[:version_name].each_byte.find{|byte| byte == 32} != nil
              raise Uhuru::RepositoryManager::Error.new('Add product error', 'The version name can not have white spaces.')
            end

            session[:upload_state_blob_id] = Uhuru::RepositoryManager::Model::Versions.create(product.id, params[:version_name], params[:type], params[:description], path)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Add version: ', ex.message)
            $logger.error("Add version via sftp : #{ex.message} - #{ex.backtrace}")
          end

          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => product.id)
          products = Uhuru::RepositoryManager::Model::Products.get_products
          render_erb do
            template :'admin/forms/edit_versions'
            layout :'layouts/layout'
            var :versions, versions
            var :products, products
            var :selected_product, selected_product
            var :selected_version, nil
            var :error_message, error_message || nil
            var :new_version, :new_version
          end
        end

        urm.get CHECK_VERSION_STATE do
          response = Uhuru::RepositoryManager::Model::Versions.create_status(session[:upload_state_blob_id])

          if response == 'Processing'
            return response
          else
            session[:upload_state_blob_id] = nil
            return response
          end
        end

        urm.post UPLOAD_VERSION_FILE do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end

          tempfile = params[:file][:tempfile]
          filename = params[:file][:filename]

          begin
            user_tmp_folder = Uhuru::RepositoryManager::Model::Users.get_users(:username => session[:username]).first.user_sys
            # remove the previous directory if any
            FileUtils.rm_rf(File.join($config[:master_mirror][:blobstore_options][:tmp_local_directory], user_tmp_folder))
            # create a new directory with the user name
            FileUtils.mkdir_p(File.join($config[:master_mirror][:blobstore_options][:tmp_local_directory], user_tmp_folder))
            # copy the version file that was uploaded
            FileUtils.copy(tempfile.path, File.join($config[:master_mirror][:blobstore_options][:tmp_local_directory], user_tmp_folder, filename))
            # keep the file name inside a session variable
            session[:version_file_name] = filename
            # change permision
            path_to_file = File.join($config[:master_mirror][:blobstore_options][:tmp_local_directory], user_tmp_folder, filename)
            `chown #{$config[:master_mirror][:blobstore_options][:user]} #{path_to_file}`
          rescue Exception => ex
            $logger.error("Upload version file : #{ex.message} - #{ex.backtrace}")
          end
        end

        urm.post DELETE_VERSION do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          version = Uhuru::RepositoryManager::Model::Versions.get_versions.find{|version| version.id.to_s == params[:version]}
          Uhuru::RepositoryManager::Model::Versions.delete(version)

          if session[:is_inside_popup]
            redirect PRODUCTS + '/' + params[:product] + '/versions'
          else
            redirect PRODUCTS + '/' + params[:product]
          end
        end


        # these two post routes will be for add/remove dependencies
        #
        # ADD_DEPENDENCY      - adds a dependency to the current product version
        # DELETE_DEPENDENCY   - removes a dependency from the version
        #
        urm.post ADD_DEPENDENCY do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          child_version = Uhuru::RepositoryManager::Model::Versions.get_versions.find{|version| version.id.to_s == params[:version]}
          parent_version = Uhuru::RepositoryManager::Model::Versions.get_versions.find{|version| version.id.to_s == params[:parent_version]}

          Uhuru::RepositoryManager::Model::Dependencies.create(parent_version, child_version)

          redirect PRODUCTS + '/' + params[:product] + '/versions/' + params[:version]
        end

        urm.post DELETE_DEPENDENCY do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          version  = Uhuru::RepositoryManager::Model::Versions.get_versions.find{|version| version.id.to_s == params[:version]}
          dependency = version.dependencies.find{|dependency| dependency.id.to_s == params[:dependency]}
          Uhuru::RepositoryManager::Model::Dependencies.delete(dependency)

          redirect PRODUCTS + '/' + params[:product] + '/versions/' + params[:version]
        end

      end
    end
  end
end