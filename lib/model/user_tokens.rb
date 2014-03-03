require "configure_db"

module Uhuru::RepositoryManager::Model
  # class that handles mirrors objects
  class UserTokens

    # creates a random user token
    # user: user to add the token for
    # expiration_date = when the token is going to expire
    # type = the type of token (e.g. signup, passwordreset, etc.)
    #
    def self.create(user, expiration_date, type)
      UserToken.create(
          :user_id => user.id,
          :token => SecureRandom.urlsafe_base64(nil, false),
          :expiration_date => expiration_date,
          :type => type)
    end

    # deletes a token from the database
    #
    def self.delete(token)
      token.destroy
    end

    # gets a token from the database
    # token = the token to retrieve
    #
    def self.get_token(token)
      UserToken.where(:token => token)
    end
  end
end

# sequel class for mirror
class UserToken < Sequel::Model
  plugin :validation_helpers
  many_to_one :user

  def validate
    super

    validates_presence [:token, :expiration_date, :type, :user_id]
    validates_unique :token
  end
end