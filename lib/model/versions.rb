require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles version objects
  class Versions

    # creates a version in db, and uploads bits to master mirror
    # release_date = release date of a version
    # name = name of the version, must be unique
    # type = type of the version (alpha/beta/RC/final/nightly)
    # description = bullet point list containing modifications for the current version
    # file_path = path to a tar.gz file that contains version bits
    # stable and public have the false value as default
    #
    def self.create(product_id, name, type, description, file_path)
      blob_id = SecureRandom.hex
      size = File.size(file_path)
      sha = Digest::SHA1.file(file_path).hexdigest
      version_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], blob_id)
      error_file_path =  File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{blob_id}_error")

      Thread.new do
        begin
          file= File.new(file_path, 'r')
          client = Uhuru::RepositoryManager::Client.new
          client.upload(blob_id, file)

          version = Version.create(:product_id => product_id,
                          :release_date => DateTime.now,
                          :name => name,
                          :type => type,
                          :description => description,
                          :stable => false,
                          :public => false,
                          :object_id => blob_id,
                          :size => size,
                          :sha => sha)

          if !(version.product.type == 'ucc')
            Uhuru::RepositoryManager::FilesystemHandler.add_group(blob_id, version_path)
            Uhuru::RepositoryManager::FilesystemHandler.add_symlink(version)
          else
            ucc_private_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_private")
            `bash generate_debs_list.sh add #{version_path} #{ucc_private_path}`
          end
          # remove the temp file when ready
          FileUtils.rm_rf(file_path)
        rescue Exception => ex
           File.open(error_file_path, 'w') { |file| file.write("An error occurred during the create process: #{ex.message}") }
           $logger.error("An error occurred during the create process: #{ex.message} - #{ex.backtrace}")
        end
      end
     blob_id
    end

    # Method used for the javascript polling mechanism in order to check the state of the blob-store upload progress
    #
    def self.create_status(blob_id)
      error_file_path =  File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{blob_id}_error")
      if File.exist?(error_file_path)
         error_message = File.read(error_file_path)
         return error_message
      end
      db_version = get_versions(:object_id => blob_id)
      if db_version != nil && db_version != []
         return 'Done'
      else
         return 'Processing'
      end
    end

    # updates a version object
    # version_obj = version object to be updated
    # hash = hash containing modified values, ex: {:key1 => value1, :key2 => value2}
    # second parameter in update_fields are the fields that can be updated, :missing=>:skip means that not all fields
    # must be specified
    #
    def self.update(version_obj, hash)

      # depending on initial state of the ucc version
      public_and_stable = version_obj.public && version_obj.stable

      version = Version.db.transaction do
        version_obj.lock!
        version_obj.update_fields(hash, [:name, :type, :description, :stable, :public], :missing=>:skip)
      end

      if version_obj.product.type == "ucc"
        Uhuru::RepositoryManager::FilesystemHandler.update_ucc_version(version)

        ucc_public_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_public")
        ucc_private_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_private")
        version_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], version.values[:object_id])

        if public_and_stable && (!version.public || !version.stable)
          `bash generate_debs_list.sh delete #{version_path} #{ucc_public_path}`
          `bash generate_debs_list.sh add #{version_path} #{ucc_private_path}`
        elsif version.public && version.stable
          `bash generate_debs_list.sh delete #{version_path} #{ucc_private_path}`
          `bash generate_debs_list.sh add #{version_path} #{ucc_public_path}`
        end

      else
        Uhuru::RepositoryManager::FilesystemHandler.update_version(version)
      end

      version
    end

    # deletes a version object from db and from blobstore
    # when a version gets deleted all his dependencies and dependencies where is parent are removed from db and from blobstore
    # version_obj = version to be deleted
    #
    def self.delete(version_obj)

      if (version_obj.product.type == "ucc" && version_obj.public && version_obj.stable)
        ucc_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_public")
      else
        ucc_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], "#{Uhuru::RepositoryManager::FilesystemHandler.get_ucc_group}_private")
      end

      client = Uhuru::RepositoryManager::Client.new
      blob_id = version_obj.values[:object_id]
      client.delete(blob_id) if client.blob_exists?(blob_id)

      if !(version_obj.product.type == "ucc")
        Uhuru::RepositoryManager::FilesystemHandler.delete_group(blob_id)
        Uhuru::RepositoryManager::FilesystemHandler.remove_symlink(version_obj)
      else
        version_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], blob_id)
        `bash generate_debs_list.sh delete #{version_path} #{ucc_path}`
      end

      version_obj.dependencies.each do |dependency|
        Uhuru::RepositoryManager::Model::Dependencies.delete(dependency)
      end

      version_obj.parents.each do |dependency|
        Uhuru::RepositoryManager::Model::Dependencies.delete(dependency)
      end

      version_obj.destroy

    end

    # retrieve an array of version objects from db
    # *args could be a enumeration of key => value pairs, like get_versions(:key1 => value1, :key2 => value2)
    # or a string containing SQL conditions like get_versions("key1 > value1 AND key2 = value2")
    # or not specified and will return all object get_versions()
    #
    def self.get_versions(*args)

      if args.any?
        Version.where(args[0]).to_a
      else
        Version.all
      end

    end

    # gets available versions that can be added as a dependency. a version can be added as a dependency if belongs
    # to another product and is not already added as a dependency
    # product_id = current version product's id
    # version_obj = current version object
    #
    def self.get_available_dependencies(product_id, version_obj)

      existing_dependencies = version_obj.dependencies.map {|version| version.version_id}.uniq.join(",")
      query = existing_dependencies != "" ? "AND id NOT IN (#{existing_dependencies})" : ""
      get_versions("product_id != #{product_id} #{query}")

    end

  end
end

# sequel class for version
class Version < Sequel::Model

  plugin :validation_helpers
  plugin :association_dependencies

  many_to_one :product
  one_to_many :parents, :class=>:Dependency, :key => :version_id
  one_to_many :dependencies, :class=>:Dependency, :key => :dependency_version_id

  add_association_dependencies :parents => :destroy, :dependencies => :destroy

  def validate
    super

    validates_presence [:product_id, :release_date, :name, :type, :stable, :public, :object_id, :size, :sha]
    validates_unique   [:product_id, :name]
  end
end
