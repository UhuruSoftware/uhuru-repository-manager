require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles mirrors objects
  class Mirrors

    # creates a mirror in db
    # name = name of the mirror, must be unique
    # description = description of the mirror
    # hostname = hostname of the mirror
    # status = status of the mirror (online/offline)
    # type = type of the mirror (master/slave)
    #
    def self.create(name, description, hostname, status, type = nil)

      # if mirror type is not specified, it will be a "slave" mirror
      mirror_type = type != nil ? type : "slave"

      Mirror.create(:name => name,
                     :description => description,
                     :hostname => hostname,
                     :type => mirror_type,
                     :status => status)
    end

    # updates a mirror object
    # mirror_obj = mirror object to be updated
    # hash = hash containing modified values, ex: {:key1 => value1, :key2 => value2}
    # second parameter in update_fields are the fields that can be updated, :missing=>:skip means that not all fields
    # must be specified
    #
    def self.update(mirror_obj, hash)

      Mirror.db.transaction do
        mirror_obj.lock!
        mirror_obj.update_fields(hash, [:name, :description, :hostname, :status], :missing=>:skip)
      end

    end

    # deletes a mirror object from db
    #
    def self.delete(mirror_obj)

      mirror_obj.destroy

    end

    # retrieve an array of mirror objects from db
    # *args could be a enumeration ok key => value pairs, like get_versions(:key1 => value1, :key2 => value2)
    # or a string containing SQL conditions like get_versions("key1 > value1 AND key2 = value2")
    # or not specified and will return all object get_mirrors()
    #
    def self.get_mirrors(*args)

      if args.any?
        Mirror.where(args[0]).to_a
      else
        Mirror.all
      end

    end

    # retrieve an array of mirrors online mirrors, the default mirror is generated from config file, and the rest from db
    def self.get_dashboard_mirrors
      Mirror.where(:status => true)
    end

  end
end

# sequel class for mirror
class Mirror < Sequel::Model

  plugin :validation_helpers

  def validate
    super

    validates_presence [:name, :hostname, :type, :status]
    validates_unique :name
  end
end