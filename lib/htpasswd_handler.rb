require "webrick"

module Uhuru::RepositoryManager
  # class that handles .httpasswd files, used for adding and removing user password pairs to passwords file
  # only users in password file will have access to blobstore directory
  #
  class HtpasswdHandler

    # loads password file from config
    @file_path = $config[:path_password_file]

    # adds a new user password pair in passwords file
    # file_path = path to password file
    # username = username to add to file
    # password = password of the user, will be saved encrypted
    #
    def self.create_password(username, password)

      htpasswd = WEBrick::HTTPAuth::Htpasswd.new(@file_path)
      htpasswd.set_passwd(nil, username, password)
      htpasswd.flush

    end

    # removes a user password pair in passwords file
    # file_path = path to password file
    # username = username to be removed from file
    #
    def self.delete_password(username)

      htpasswd = WEBrick::HTTPAuth::Htpasswd.new(@file_path)
      htpasswd.delete_passwd(nil, username)
      htpasswd.flush

    end

    # returns true if the password for user is the same in passwords file, else false
    # file_path = path to password file
    # username = username to verify the password for
    # password = password to check
    #
    def self.valid_password?(username, password)

      htpasswd = WEBrick::HTTPAuth::Htpasswd.new(@file_path)
      file_password = htpasswd.get_passwd(nil, username, false)

      if file_password != nil
        file_password == password.crypt(file_password[0..1])
      else
        return nil
      end

    end

    # returns the encrypted password
    def self.get_password(username)

      htpasswd = WEBrick::HTTPAuth::Htpasswd.new(@file_path)
      htpasswd.get_passwd(nil, username, false)

    end


    # checks if a user exists in passwords file
    # file_path = path to password file
    # username = username to be checked if exists
    # returns true if exists, false otherwise
    #
    def self.username_exists?(username)

      htpasswd = WEBrick::HTTPAuth::Htpasswd.new(@file_path)
      password = htpasswd.get_passwd(nil, username, false)
      password != nil

    end

  end
end
