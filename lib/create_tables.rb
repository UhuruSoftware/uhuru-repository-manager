require "configure_db"

module Uhuru::RepositoryManager
  # class used for creating tables in db
  class CreateTables

    # constructor initializes database connection
    def initialize(db)
      @db = db
    end

    # method that creates the tables in the db
    def create_tables
      create_mirrors
      create_users
      create_user_tokens
      create_products
      create_users_products
      create_versions
      create_dependencies
      create_access_keys
    end

    # checks that all tables are present in db
    def exist_tables?
      @db.tables.sort == [:mirrors, :users, :user_tokens, :products, :products_users, :versions, :dependencies, :access_keys].sort
    end

    # create mirrors table
    def create_mirrors
      @db.create_table(:mirrors) do
        primary_key      :id
        String           :name,         :index => true
        String           :description
        String           :hostname
        String           :type,         :default => "slave"
        FalseClass       :status,       :default => false
      end
      Mirror.dataset = Mirror.dataset

    end

    # create users table
    def create_users
      @db.create_table(:users) do
        primary_key      :id
        DateTime         :created_at
        DateTime         :updated_at
        String           :username,     :index => true
        String           :user_sys
        String           :first_name
        String           :last_name
        String           :organization
        String           :job_title
        String           :country
        String           :city
        String           :address
        String           :phone
        FalseClass       :admin,        :default => false
        FalseClass       :active,       :default => false
      end
      Sequel::Model::User.dataset = Sequel::Model::User.dataset
    end

    # create users table
    def create_user_tokens
      @db.create_table(:user_tokens) do
        primary_key       :id
        String            :token,             :index => true
        DateTime          :expiration_date
        String            :type
        foreign_key       :user_id, :users, :index => true
      end
      Sequel::Model::UserToken.dataset = Sequel::Model::UserToken.dataset
    end

    # create products table
    def create_products
      @db.create_table(:products) do
        primary_key      :id
        String           :name,         :index => true
        String           :type,         :index => true
        String           :label
        String           :description
      end
      Product.dataset = Product.dataset

    end

    # create users_products join table
    def create_users_products
      @db.create_join_table(:user_id => :users, :product_id => :products) do
      end
    end

    # create versions table
    def create_versions
      @db.create_table(:versions) do
        primary_key      :id
        DateTime         :release_date, :index => true
        String           :name
        String           :type
        String           :description
        FalseClass       :stable,       :default => false
        FalseClass       :public,       :default => false
        String           :object_id
        String           :size
        String           :sha
        foreign_key      :product_id, :products
      end
      Version.dataset = Version.dataset

    end

    # create dependencies table
    def create_dependencies
      @db.create_table(:dependencies) do
        primary_key      :id
        foreign_key      :version_id, :versions, :index => true
        foreign_key      :dependency_version_id, :versions, :index => true
      end
      Dependency.dataset = Dependency.dataset
    end

    # create access_keys table
    def create_access_keys
      @db.create_table(:access_keys) do
        primary_key      :id
        String           :name
        String           :value
        foreign_key      :user_id, :users, :index => true
      end
      AccessKey.dataset = AccessKey.dataset
    end
  end
end