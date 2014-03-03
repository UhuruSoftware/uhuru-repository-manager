#
#    The route base for the Uhuru Repository Manager
#

module Uhuru
  module RepositoryManager

      #
      #   main routes
      #

      INDEX                     = '/'
      NOT_ADMIN                 = "#{INDEX}login/user/not_admin"
      NOT_LOGGED_IN             = "#{INDEX}login/user/not_logged_in"
      LOGIN                     = "#{INDEX}login"
      SIGNUP                    = "#{INDEX}signup"
      ACTIVATE                  = "#{INDEX}activate/:token"
      FORGOT_PASSWORD           = "#{INDEX}forgot_password"
      EMAIL_SENT                = "#{INDEX}email_sent"
      PASSWORD_RESET            = "#{INDEX}password_reset/:token"
      LOGOUT                    = "#{INDEX}logout"

      USER_HOWTO                = "#{INDEX}howto"
      USER_DASHBOARD            = "#{INDEX}user_dashboard"
      USER_KEYS                 = "#{INDEX}keys"
      USER_ADD_KEY              = "#{INDEX}add_key"
      USER_DELETE_KEY           = "#{INDEX}delete_key"
      USER_ACCOUNT_SETTINGS     = "#{INDEX}account_settings"

      DASHBOARD                 = "#{INDEX}dashboard"
      PRODUCTS                  = "#{INDEX}products"
      VERSIONS                  = "#{PRODUCTS}/:product/versions"
      MIRRORS                   = "#{INDEX}mirrors"
      USERS                     = "#{INDEX}users"
      ACCESS                    = "#{INDEX}access"
      ADMIN_KEYS                = "#{INDEX}admin_keys"
      ADMIN_ADD_KEY             = "#{INDEX}admin_add_key"
      ADMIN_DELETE_KEY          = "#{INDEX}admin_delete_key"
      ADMIN_ACCOUNT_SETTINGS    = "#{INDEX}admin_account_settings"

      #
      #  sections and forms
      #

      EDIT_PRODUCT              = "#{PRODUCTS}/:product"
      ADD_PRODUCT               = "#{PRODUCTS}/add/new"
      DELETE_PRODUCT            = "#{PRODUCTS}/:product/delete"

      EDIT_VERSION              = "#{VERSIONS}/:version"
      ADD_VERSION               = "#{PRODUCTS}/:product/versions/add/new"
      ADD_VERSION_VIA_SFTP      = "#{PRODUCTS}/:product/versions/add/new_sftp"
      UPLOAD_VERSION_FILE       = "#{PRODUCTS}/:product/versions/add/upload_file"
      CHECK_VERSION_STATE       = "#{PRODUCTS}/check/version/state/progress"
      DELETE_VERSION            = "#{VERSIONS}/:version/delete"

      ADD_DEPENDENCY            = "#{VERSIONS}/:version/add_dependency"
      DELETE_DEPENDENCY         = "#{VERSIONS}/:version/delete_dependency"
      REFRESH_DEPENDENCIES      = "#{VERSIONS}/:version/:selected_product/refresh"



      EDIT_MIRROR               = "#{MIRRORS}/:mirror"
      ADD_MIRROR                = "#{MIRRORS}/add/new"
      DELETE_MIRROR             = "#{MIRRORS}/:mirror/delete"

      EDIT_USER                 = "#{USERS}/:user"
      ADD_USER                  = "#{USERS}/add/new"
      DELETE_USER               = "#{USERS}/:user/delete"

      EDIT_ACCESS               = "#{ACCESS}/:user"
      CHANGE_ACCESS_STATE       = "#{ACCESS}/:user"

      GET_PRODUCTS_MANIFEST     = "#{INDEX}:user_sys/products"
      GET_PRODUCT_MANIFEST      = "#{INDEX}:user_sys/:product_name"
  end
end