#
#    The route base for the Uhuru Repository Manager
#

module Uhuru
  module RepositoryManager
      INDEX                     = '/'
      LOGIN                     = "#{INDEX}login"
      SIGNUP                    = "#{INDEX}signup"
      LOGOUT                    = "#{INDEX}logout"

      USER_HOWTO                = "#{INDEX}howto"
      USER_MIRRORS              = "#{INDEX}mirrors"

      ADMIN_PRODUCTS            = "#{INDEX}products"
      ADMIN_MIRRORS             = "#{INDEX}admin_mirrors"
      ADMIN_USERS               = "#{INDEX}users"
      ADMIN_ACCESS              = "#{INDEX}access"
  end
end