module Uhuru::RepositoryManager
  # class that generates and add components to manifest

  class ManifestGenerator

    # generates the content as a yaml format of products.yml file depending on a user, if no user is specified will
    # generate the content of a guest user (only public and stable products)
    # user_obj = user to generate the file for
    #
    def self.generate_products_yml(user_obj = nil)

      if user_obj
        products = Uhuru::RepositoryManager::Model::Products.get_user_products(user_obj)
      else
        products = Uhuru::RepositoryManager::Model::Products.get_guest_products
      end

      products_content = {}
      products_content["products"] = {}

      products.each do |product|
        product_item = {}
        product_item["label"] = product.label
        product_item["description"] = product.description
        product_item["type"] = product.type

        products_content["products"][product.name] = product_item
      end

      YAML::dump(products_content)

    end

    # generates the content as a yaml format of manifest.yml file for a product depending on the user if is guest or not
    # product_obj = product to generate the versions file for
    # guest = true if manifest will be generated for a guest, if not will be generated for user
    #
    def self.generate_manifest_yml(product_obj, guest)

      product_id = product_obj.id

      if guest
        versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => product_id, :stable => true, :public => true)
      else
        versions = Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => product_id, :stable => true)
      end

      versions_content = {}
      versions_content["versions"] = {}

      versions.each do |version|
        location = {}
        location["object_id"] = version.values[:object_id]
        location["size"] = version.size.to_i
        location["sha"] = version.sha

        version_item = {}
        version_item["type"] = version.type
        version_item["description"] = version.description
        version_item["location"] = location

        dependencies = generate_dependencies_yml(version)

        version_item["dependencies"] = dependencies
        versions_content["versions"][version.name] = version_item
      end

      YAML::dump(versions_content)

    end

    private

    # generate a list of dependencies as a yml format for a version
    # version = the version for which to generate the dependencies
    #
    def self.generate_dependencies_yml(version)
      dependencies = []

      version.dependencies.each do |dependency|
        child_version = dependency.parent_version

        dependency_item = {}
        dependency_item["dependency"] = child_version.product.name
        dependency_item["version"] = []
        dependency_item["version"] << child_version.name

        dependencies << dependency_item
      end

      dependencies
    end

  end
end
