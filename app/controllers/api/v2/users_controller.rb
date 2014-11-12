module Api
  module V2
    class UsersController < ApiV2Controller
      before_filter :authenticate_oauth_user!
      # doorkeeper_for :all

      def current
        result = {
          access_token: {
            application: doorkeeper_token.application.name,
            scope: oauth_scope,
            # token_refresh_in: doorkeeper_token.expires_in
          }
        }
        result[:user] = user_info if oauth_scope.include?('read_user')
        result[:bike_ids] = bike_info if oauth_scope.include?('read_bikes')
        respond_with result
      end

      private
      
      def user_info
        {
          username: @oauth_user.username,
          email: @oauth_user.email
        }
      end
      
      def bikes_info
        @oauth_user.bikes
      end
     
    end
  end
end