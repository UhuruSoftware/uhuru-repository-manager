require 'rubygems'
require 'sinatra'
require 'sinatra/base'


module Uhuru::MirrorProxy
  class Main < Sinatra::Base

    get  "/:user_sys/:product_name" do
      begin

        user_sys = params[:user_sys]
        product_name = params[:product_name]
        if request.ip == "127.0.0.1"
          begin
            `ssh #{$config[:master_mirror]} -p #{$config[:ssh_port]} curl localhost/#{user_sys}/#{product_name}`
          end
        end
      rescue => ex
        puts "Get products manifest for user: #{user_sys}. Failed ERROR: #{ex.message} - #{ex.backtrace}"
      end
    end

  end
end


