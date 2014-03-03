#
#    The products and versions section for the urm
#

module Uhuru
  module RepositoryManager
    module Products
      def self.registered(urm)

        # this is the main products page, a list of product will be shown on the left side
        # the right side will NOT be populated with product details
        #
        urm.get PRODUCTS do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/products'
            layout :'layouts/layout'
            var :products, products
            var :selected_product, nil
          end
        end

        # this page is an extension of the products page above
        # in the right side of the page will be shown the selected product details with 2 sub-tabs
        #
        # a properties tab  ----> which will be the update and save an existing product
        # a versions tab    ----> which will have a brief summary of the product versions
        #
        urm.get EDIT_PRODUCT do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          products = Uhuru::RepositoryManager::Model::Products.get_products
          product = params[:product]
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])

          render_erb do
            template :'admin/products'
            layout :'layouts/layout'
            var :products, products
            var :selected_product, product
            var :versions, versions
          end
        end

        # this page is an extension of the product page above
        # in the right side of the page will be shown a blank form for adding a new product with blank fields by default
        #
        urm.get ADD_PRODUCT do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          products = Uhuru::RepositoryManager::Model::Products.get_products

          render_erb do
            template :'admin/products'
            layout :'layouts/layout'
            var :products, products
            var :selected_product, nil
            var :new_product, :new_product
          end
        end


        # These are the post methods for the actions specified above
        #
        # EDIT_PRODUCT     - the post method for update selected product
        # ADD_PRODUCT      - the post method for adding a new product
        # DELETE_PRODUCT   - the post method for removing a product from the list
        urm.post EDIT_PRODUCT do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          product = Uhuru::RepositoryManager::Model::Products.get_products.find{|product| product.id.to_s == params[:product]}

          hash = {
                    :name => params[:product_name],
                    :description => params[:description],
                    :type => params[:type],
                    :label => params[:label]
                 }

          begin
            Uhuru::RepositoryManager::Model::Products.update(product, hash)
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Edit product: ', ex.message)
            $logger.error("Edit product : #{ex.message} - #{ex.backtrace}")
          end

          products = Uhuru::RepositoryManager::Model::Products.get_products
          versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => params[:product])
          render_erb do
            template :'admin/products'
            layout :'layouts/layout'
            var :products, products
            var :versions, versions
            var :selected_product, product.id
            var :error_message, error_message || nil
          end
        end

        urm.post ADD_PRODUCT do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          products = Uhuru::RepositoryManager::Model::Products.get_products

          begin
            if params[:product_name].each_byte.find{|byte| byte == 32} != nil
              raise Uhuru::RepositoryManager::Error.new('Add product error', 'The product name can not have white spaces.')
            end

            Uhuru::RepositoryManager::Model::Products.create(params[:product_name], params[:type], params[:label], params[:description])
          rescue Exception => ex
            error_message = Uhuru::RepositoryManager::Error.new('Create product: ', ex.message)
            $logger.error("Create product : #{ex.message} - #{ex.backtrace}")
          end

          products = Uhuru::RepositoryManager::Model::Products.get_products
          render_erb do
            template :'admin/products'
            layout :'layouts/layout'
            var :products, products
            var :selected_product, nil
            var :error_message, error_message || nil
            var :new_product, :new_product
          end
        end

        urm.post DELETE_PRODUCT do
          unless logged_in_as_admin?
            redirect NOT_ADMIN
          end
          product = Uhuru::RepositoryManager::Model::Products.get_products.find{|product| product.id.to_s == params[:product]}
          Uhuru::RepositoryManager::Model::Products.delete(product)

          redirect PRODUCTS
        end
      end
    end
  end
end