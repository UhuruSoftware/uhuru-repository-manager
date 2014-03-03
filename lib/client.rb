module Uhuru::RepositoryManager
  # class that handles blobstore_client gem, used for uploading or deleting files in master mirror
  class Client

    # initializes blobstore client from config and create a instance for client
    def initialize
      master_mirror = $config[:master_mirror]

      @blobstore_client = Bosh::Blobstore::Client.create(master_mirror[:blobstore_provider], master_mirror[:blobstore_options])
    end

    # uploads content(string or files) to a blob on the blobstore server
    # id = blob id on the server
    # content = content on the blob
    #
    def upload(id, content)
      if blob_exists?(id)
        delete(id)
      end
      @blobstore_client.create(content, id)
    end

    # gets an object from blobstore server or nil if doesn't exists
    # id = blob id on the server
    #
    def get(id)
      if @blobstore_client.exists?(id)
        return @blobstore_client.get(id)
      else
        return nil
      end
    end

    # deletes an object from blobstore server
    # id = blob id on the server
    #
    def delete(id)
      @blobstore_client.delete(id)
    end

    # checks if an object exists on blobstore server
    # blob_id = blob id on the server
    #
    def blob_exists?(blob_id)
      @blobstore_client.exists?(blob_id)
    end
  end
end
