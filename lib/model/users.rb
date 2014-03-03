require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles user objects
  class Users

    # creates a user in db
    # username = an valid email for login, must be unique
    # first_name = first name of the user
    # last_name = last name of the user
    # organization = organization the user belongs to
    # admin = if user is admin or not
    # active always is true
    #
    def self.create(username, first_name, last_name, organization, job_title, country, city = nil, address = nil, phone = nil, admin = nil, default_user_sys = nil)

      is_admin = admin != nil ? true : false
      datetime = DateTime.now
      user_sys = default_user_sys || SecureRandom.hex

      user = User.create(:created_at => datetime,
                  :updated_at => datetime,
                  :username => username,
                  :user_sys => user_sys,
                  :first_name => first_name,
                  :last_name => last_name,
                  :organization => organization,
                  :job_title => job_title,
                  :country => country,
                  :address => address,
                  :phone => phone,
                  :city => city,
                  :admin => is_admin,
                  :active => false)

      Uhuru::RepositoryManager::FilesystemHandler.create_user(user)

      user
    end

    # updates a user object
    # user_obj = user object to be updated
    # hash = hash containing modified values, ex: {:key1 => value1, :key2 => value2}
    # second parameter in update_fields are the fields that can be updated, :missing=>:skip means that not all fields
    # must be specified
    #
    def self.update(user_obj, hash)

      User.db.transaction do
        user_obj.lock!
        user_obj.update_fields(hash, [:updated_at, :first_name, :last_name, :organization, :job_title, :country, :city, :address, :phone, :admin, :active], :missing=>:skip)
      end

    end

    # deletes a user object from db
    #
    def self.delete(user_obj)

      Uhuru::RepositoryManager::HtpasswdHandler.delete_password(user_obj.username)
      Uhuru::RepositoryManager::FilesystemHandler.delete_user(user_obj.user_sys)
      user_obj.destroy

    end

    # retrieve an array of user objects from db
    # *args could be a enumeration ok key => value pairs, like get_versions(:key1 => value1, :key2 => value2)
    # or a string containing SQL conditions like get_versions("key1 > value1 AND key2 = value2")
    # or not specified and will return all object get_users()
    #
    def self.get_users(*args)

      if args.any?
        User.where(args[0]).to_a
      else
        User.all
      end

    end

    # add access for a user to a product
    # user_obj = user to add access to
    # product_obj = product to which user will have access
    #
    def self.add_product_access(user_obj, product_obj)

      user_obj.add_product(product_obj)

      product_obj.versions.each do |version|
        Uhuru::RepositoryManager::FilesystemHandler.add_access(version, user_obj)
      end

      user_obj
    end

    # remove access for a user to a product
    # user_obj = user to remove access from
    # product_obj = product to which user will not have access
    #
    def self.remove_product_access(user_obj, product_obj)

      user_obj.remove_product(product_obj)

      product_obj.versions.each do |version|
        if product_obj.type == "ucc"
          Uhuru::RepositoryManager::FilesystemHandler.remove_ucc_access(version, user_obj)
        else
          Uhuru::RepositoryManager::FilesystemHandler.remove_access(version, user_obj)
        end
      end

    end

  end
end

# sequel class for user
class User < Sequel::Model

  plugin :validation_helpers
  plugin :association_dependencies

  many_to_many :products
  one_to_many :access_keys
  one_to_many :user_tokens

  add_association_dependencies :products => :nullify, :access_keys => :destroy, :user_tokens => :delete

  def validate
    super

    validates_presence [:created_at, :username, :first_name, :last_name, :organization, :job_title, :country, :admin, :active, :user_sys]
    validates_unique :username
    validates_unique :user_sys
    validates_format /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i, :username
  end
end