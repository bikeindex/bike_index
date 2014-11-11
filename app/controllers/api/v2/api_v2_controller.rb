module Api
  module V2
    class ApiV2Controller < ApplicationController
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers
      respond_to :json

      private
      def oauth_user
        if doorkeeper_token
          @oauth_user ||= User.find(doorkeeper_token.resource_owner_id)
        end
      end

      def oauth_scope
        doorkeeper_token.scopes
      end

      def authenticate_oauth_user!
        unless oauth_user.present?
          message = { error: "401 - Unauthorized! Either you aren't logged in, or you don't have permission to view this page" }
          respond_with message, status: 401 and return
        end
      end
      
    end
  end
end