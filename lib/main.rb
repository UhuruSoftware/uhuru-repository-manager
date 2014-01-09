#
#    The main class for the URM(Uhuru Repository Manager)
#    This file will include all the necessary libraries abd routes,
#    also will set the file system inside the project and have the index page route
#

require 'rubygems'
require 'sinatra'

require '../lib/routes/route_base'
require '../lib/routes/core'
require '../lib/routes/guest'
require '../lib/routes/admin'
require '../lib/routes/user'


module Uhuru::RepositoryManager
  class RepositoryManager < Sinatra::Base

    set :root, File.expand_path("../../", __FILE__)
    set :views, File.expand_path("../../views", __FILE__)
    set :public_folder, File.expand_path("../../public", __FILE__)

    register Uhuru::RepositoryManager::Core
    register Uhuru::RepositoryManager::Guest
    register Uhuru::RepositoryManager::Admin
    register Uhuru::RepositoryManager::User

    get INDEX do
      erb :'guest/index', :layout => :'layouts/layout'
    end
  end
end
