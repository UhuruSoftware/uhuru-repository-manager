require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles dependency objects

  class Dependencies
    # creates a dependency in db
    # parent_version = parent version object
    # child_id = dependent version object
    #
    def self.create(parent_version, child_version)

      dependency = Dependency.new
      dependency.parent_version = parent_version
      dependency.child_version = child_version
      dependency.save

    end

    # deletes a dependency object from db
    # dependency_obj = dependency relation to be deleted
    # after delete, the versions involved will be refreshed to not display dependencies in associations
    #
    def self.delete(dependency_obj)

      dependency_obj.delete
      parent_version = dependency_obj.parent_version
      parent_version.refresh
      child_version = dependency_obj.child_version
      child_version.refresh
      dependency_obj

    end

  end

end

# sequel class for dependency
class Dependency < Sequel::Model

  plugin :validation_helpers
  plugin :association_dependencies

  many_to_one :parent_version, :class => :Version, :key => :version_id
  many_to_one :child_version, :class => :Version, :key => :dependency_version_id

  add_association_dependencies :parent_version => :destroy, :child_version => :destroy

  def validate
    super

    validates_presence [:version_id, :dependency_version_id]
    validates_unique   [:version_id, :dependency_version_id]
  end
end