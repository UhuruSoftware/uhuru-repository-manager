module Uhuru::RepositoryManager
  # class that handles user account, groups and symlinks
  class FilesystemHandler
    UCC_GROUP = "ucc"
    USER_DISTS = "dists"

    def self.get_ucc_group
      UCC_GROUP
    end

    # when an version is created will create the group too, and will set proper permissions and ownership
    # group_name = group name for the version
    # path = path to the location on the version bits
    #
    def self.add_group(group_name, path)

      `groupadd #{group_name}`
      `chown root.#{group_name} #{path}`
      `chmod 040 #{path}`

    end

    # when an version gets deleted will delete the group too
    # group_name = group name for the version
    #
    def self.delete_group(group_name)
      `groupdel #{group_name}`

    end

    # add symlink for all users to version
    # version_obj = version object from db
    # user = user obj from db to redo access management
    #
    def self.add_symlink(version_obj)
      blobstore_id = version_obj.values[:object_id]
      version_path = File.join($config[:master_mirror][:blobstore_options][:blobstore_path], blobstore_id)
      Uhuru::RepositoryManager::Model::Users.get_users.each do |user|
        user_sys = user.user_sys
        user_version_path = File.join($config[:path_home_user], user_sys, blobstore_id)

        `ln -s #{version_path} #{user_version_path}`
      end

    end

    # remove symlink for all users to version
    # version_obj = version object from db
    # user = user obj from db to redo access management
    #
    def self.remove_symlink(version_obj)
      blobstore_id = version_obj.values[:object_id]
      Uhuru::RepositoryManager::Model::Users.get_users.each do |user|
        user_sys = user.user_sys
        user_version_path = File.join($config[:path_home_user], user_sys, blobstore_id)

        `[ -h #{user_version_path} ] && rm -f #{user_version_path}`
      end

    end

    # when an version is updated will redo all symlinks and user management in version group
    # version_obj = version object from db
    #
    def self.update_version(version_obj)
      blobstore_id = version_obj.values[:object_id]

      Uhuru::RepositoryManager::Model::Users.get_users.each do |user|
        user_sys = user.user_sys

        # remove users from version group
        `[ ! -z "\`cat /etc/group|grep #{user_sys}|grep #{blobstore_id}\`" ] && gpasswd -d #{user_sys} #{blobstore_id}`

        # for guests add user to group
        if version_obj.public && version_obj.stable
          `gpasswd -a #{user_sys} #{blobstore_id}`
        elsif !version_obj.public && version_obj.stable

          # check if user has access, add user to group
          if version_obj.product.users.include?(user)
            `gpasswd -a #{user_sys} #{blobstore_id}`
          end
        end
      end

    end

    # when a UCC version is updated will redo user management in ucc public and private groups
    # version_obj = version object from db
    #
    def self.update_ucc_version(version_obj)

      # only if the ucc version is the last one that is public and stable should remove users from ucc public group
      last_ucc_public = false
      Uhuru::RepositoryManager::Model::Products.get_products(:type => "ucc").each do |ucc_product|
        next if ucc_product.is_public? && ucc_product.is_stable?
        last_ucc_public = true
        break
      end

      Uhuru::RepositoryManager::Model::Users.get_users.each do |user|
        user_sys = user.user_sys

        # remove user from UCC public group if is the last public and stable ucc
        if last_ucc_public
          `[ ! -z "\`cat /etc/group|grep #{user_sys}|grep #{UCC_GROUP}_public\`" ] && gpasswd -d #{user_sys} #{UCC_GROUP}_public`
        end
        # remove user from ucc private group
        `[ ! -z "\`cat /etc/group|grep #{user_sys}|grep #{UCC_GROUP}_private\`" ] && gpasswd -d #{user_sys} #{UCC_GROUP}_private`

        # for guests add user to UCC group
        if version_obj.public && version_obj.stable
          `gpasswd -a #{user_sys} #{UCC_GROUP}_public`
        elsif !version_obj.public && version_obj.stable

          # check if user has access add user to UCC group
          if version_obj.product.users.include?(user)
            `gpasswd -a #{user_sys} #{UCC_GROUP}_private`
          end
        end
      end

    end

    # redo user management in version group
    # version_obj = version object from db
    # user = user obj from db to redo access management
    #
    def self.add_access(version_obj, user)
      blobstore_id = version_obj.values[:object_id]
      user_sys = user.user_sys

      # for guests create symlink and add user to group
      if version_obj.public && version_obj.stable
        `gpasswd -a #{user_sys} #{blobstore_id}`
      elsif !version_obj.public && version_obj.stable

        # check if user has access, create symlink and add user to group
        if version_obj.product.users.include?(user)
          `gpasswd -a #{user_sys} #{blobstore_id}`
        end
      end
    end

    # add user to ucc public or private groups
    # version_obj = version object from db
    # user = user obj from db to redo access management
    #
    def self.add_ucc_access(version_obj, user)
      user_sys = user.user_sys

      # for guests add user to UCC group
      if version_obj.public && version_obj.stable
        ucc_public_group = "#{UCC_GROUP}_public"
        `gpasswd -a #{user_sys} #{ucc_public_group}`
      elsif !version_obj.public && version_obj.stable

        # check if user has access, add user to UCC group
        if version_obj.product.users.include?(user)
          ucc_private_group = "#{UCC_GROUP}_private"
          `gpasswd -a #{user_sys} #{ucc_private_group}`
        end
      end
    end


    # remove user from version group
    # version_obj = version object from db
    # user = user obj from db to redo access management
    #
    def self.remove_access(version_obj, user)
      blobstore_id = version_obj.values[:object_id]
      user_sys = user.user_sys

      # remove symlinks and user from version group for non public products
      if !(version_obj.public && version_obj.stable)
        `[ ! -z "\`cat /etc/group|grep #{user_sys}|grep #{blobstore_id}\`" ] && gpasswd -d #{user_sys} #{blobstore_id}`
      end

    end

    # remove user from UCC group
    # version_obj = version object from db
    # user = user obj from db to redo access management
    #
    def self.remove_ucc_access(version_obj, user)
      user_sys = user.user_sys

      # remove user from UCC group for non public products
      if !(version_obj.public && version_obj.stable)
        `[ ! -z "\`cat /etc/group|grep #{user_sys}|grep #{UCC_GROUP}\`" ] && gpasswd -d #{user_sys} #{UCC_GROUP}`
      end
    end

    # will create home user directory and create user account in the system
    # user_sys = system user that will be created
    # user_comment = user real first name and last name
    #
    def self.create_user(user)
      user_sys = user.user_sys
      prefix = $config[:path_home_user]
      home_path = File.join(prefix, user_sys)
      blobstore_path = $config[:master_mirror][:blobstore_options][:blobstore_path]

      `test -z "$( cat /etc/passwd|grep -w ^#{user_sys} )" && useradd -d #{home_path} -m -c "#{user_sys}" #{user_sys}`

      # create .urm_port file in home user to be accessible from ucc
      File.open(File.join(prefix, user_sys, ".urm_port"), 'w+') {|file| file.write($config[:port]) }

      # create symlinks for the public and private UCC product type on the blobstore
      `ln -s #{File.join(blobstore_path, "#{UCC_GROUP}_public")} #{File.join(home_path, USER_DISTS)}`
      `ln -s #{File.join(blobstore_path, "#{UCC_GROUP}_private")} #{File.join(home_path, USER_DISTS)}`

      # create symlinks for all existing versions, and adds corresponding access
      Uhuru::RepositoryManager::Model::Versions.get_versions.each do |version|
        if version.product.type == "ucc"
          self.add_ucc_access(version, user)
        else
          blobstore_id = version.values[:object_id]

          `ln -s #{File.join(blobstore_path, blobstore_id)} #{File.join(home_path, blobstore_id)}`
          self.add_access(version, user)
        end
      end

    end

    # will remove a user account in the system recursively, except for the admin system user
    # user_sys = system user to be deleted
    def self.delete_user(user_sys)

      if (user_sys != $config[:master_mirror][:blobstore_options][:user])
        `userdel -r -f #{user_sys}`
      end

    end

    # adds a ssh key of a user to the authorized_keys file of the user
    # value = value of the key
    # user_sys = owner of the key
    def self.add_ssh_key(value, user_sys)
      if (user_sys == $config[:master_mirror][:blobstore_options][:user])
        home_path = `cat /etc/passwd|grep -w ^#{user_sys}|cut -f 6 -d \:`
        home_path = home_path.gsub("\n",'')
      else
        home_path = File.join($config[:path_home_user], user_sys)
      end

      `test -d #{home_path}/.ssh || ( mkdir -p #{home_path}/.ssh ; chown -R #{user_sys}.#{user_sys} #{home_path}/.ssh )`
      `echo "#{value}" >>#{home_path}/.ssh/authorized_keys ; chmod 0600 #{home_path}/.ssh/authorized_keys ; chown #{user_sys}.#{user_sys} #{home_path}/.ssh/authorized_keys`
    end

    # removes a ssh key of a user from the authorized_keys file of the user
    # value = value of the key
    # user_sys = owner of the key
    def self.remove_ssh_key(value, user_sys)
      if (user_sys == $config[:master_mirror][:blobstore_options][:user])
        home_path = `cat /etc/passwd|grep -w ^#{user_sys}|cut -f 6 -d \:`
        home_path = home_path.gsub("\n",'')
      else
        home_path = File.join($config[:path_home_user], user_sys)
      end

      `cat #{home_path}/.ssh/authorized_keys | grep -v "#{value}" > #{home_path}/.ssh/authorized_keys.tmp`
      `mv -f #{home_path}/.ssh/authorized_keys.tmp #{home_path}/.ssh/authorized_keys ; chmod 0600 #{home_path}/.ssh/authorized_keys ; chown #{user_sys}.#{user_sys} #{home_path}/.ssh/authorized_keys`
    end

  end
end

