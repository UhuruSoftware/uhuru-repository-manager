require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles product objects
  class Products

    # creates a product in db, and creates a blob for the product on master mirror
    # name = name of the product, must be unique
    # type = type of the product (stemcell/software/ucc)
    # label = label of the product
    # description = description of the product
    #
    def self.create(name, type, label, description)

      Product.create(:name => name,
                   :type => type,
                   :label => label,
                   :description => description)
    end

    # updates a product object
    # product_obj = product object to be updated
    # hash = hash containing modified values, ex: {:key1 => value1, :key2 => value2}
    # second parameter in update_fields are the fields that can be updated, :missing=>:skip means that not all fields
    # must be specified
    #
    def self.update(product_obj, hash)

      Product.db.transaction do
        product_obj.lock!
        product_obj.update_fields(hash, [:name, :label, :description], :missing=>:skip)
      end

    end

    # deletes a product object from db and from blobstore
    # when a product gets deleted all his versions are removed from db and from blobstore
    # product_obj = product to be deleted
    #
    def self.delete(product_obj)

      product_obj.versions.each do |version|
        Uhuru::RepositoryManager::Model::Versions.delete(version)
      end

      product_obj.destroy

    end

    # retrieve an array of product objects from db
    # *args could be a enumeration ok key => value pairs, like get_versions(:key1 => value1, :key2 => value2)
    # or a string containing SQL conditions like get_versions("key1 > value1 AND key2 = value2")
    # or not specified and will return all object get_products()
    #
    def self.get_products(*args)

      if args.any?
        Product.where(args[0]).to_a
      else
        Product.all
      end

    end

    # returns a list of stable products depending on a user
    # user_obj = user to gets products for
    #
    def self.get_user_products(user_obj)
      products = []
      user_obj.products.each do |product|
        products << product if product.is_stable? && product.type != "ucc"
      end
      get_products.each do |product|
        products << product if product.is_stable? && product.is_public? && product.type != "ucc" && !products.include?(product)
      end

      products
    end

    # returns a list of stable and public products for guest user
    #
    def self.get_guest_products
      products = []
      get_products.each do |product|
        products << product if product.is_stable? && product.is_public? && product.type != "ucc"
      end

      products
    end

  end
end

# sequel class for product
class Product < Sequel::Model

  plugin :validation_helpers
  plugin :association_dependencies

  many_to_many :users
  one_to_many :versions

  add_association_dependencies :users => :nullify, :versions => :destroy

  # method that is called at creation and update time to check that is a valid product
  def validate
    super

    validates_presence [:name, :type, :label]
    validates_unique :name
  end

  # if a product has a public version, the product will be public
  # versions are collected from db to avoid cached versions
  #
  def is_public?

    Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => self.id, :public => true).count > 0

  end

  # if a product has a stable version, the product will be stable
  # versions are collected from db to avoid cached versions
  #
  def is_stable?

    Uhuru::RepositoryManager::Model::Versions.get_versions(:product_id => self.id, :stable => true).count > 0

  end

end
