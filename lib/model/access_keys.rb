require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles access key objects
  class AccessKeys
    # creates a access key in db and adds user ssh public key to authorized keys
    # value = value of the access key
    # user = user that owns the key
    #
    def self.create(value, name, user)

      AccessKey.create(:value => value,
                  :name => name,
                  :user_id => user.id)


      Uhuru::RepositoryManager::FilesystemHandler.add_ssh_key(value, user.user_sys)

    end

    # updates a access key object
    # access_key_obj = access key object to be updated
    # hash = hash containing modified values, ex: {:key1 => value1, :key2 => value2}
    # second parameter in update_fields are the fields that can be updated
    #
    def self.update(access_key_obj, hash)

      AccessKey.db.transaction do
        access_key_obj.lock!
        access_key_obj.update_fields(hash, [:value])
      end

    end

    # deletes a access key object from db and removes user ssh public key from authorized keys
    # access_key_obj = access key to be deleted
    #
    def self.delete(access_key_obj)

      Uhuru::RepositoryManager::FilesystemHandler.remove_ssh_key(access_key_obj.value, access_key_obj.user.user_sys)
      access_key_obj.destroy

    end

    # retrieve an array of access key objects from db for a user
    # user_id = id of the user to get the keys for
    #
    def self.get_access_keys_by_user(user_id)

      AccessKey.where(:user_id => user_id).to_a

    end
  end

end

# sequel class for access key
class AccessKey < Sequel::Model

  plugin :validation_helpers

  many_to_one :user

  def validate
    super

    validates_presence [:name, :value, :user_id]
    validates_unique :value
    validates_format Regexp.new('ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3} ([^@]+@[^@]+)'), :value
  end
end