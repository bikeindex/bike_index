module Api
  module V2
    class ApiV2Controller < ApplicationController
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers
      respond_to :json

      private
      def authenticate_current_resource_owner! 
        unless current_resource_owner.present?
          message = { error: "401 - Unauthorized! Either you aren't logged in, or you don't have permission to view this page" }
          respond_with message, status: 401 and return
        end
      end

      def current_resource_owner
        if doorkeeper_token
          User.find(doorkeeper_token.resource_owner_id)
        elsif current_user.present?
          current_user
        end
      end
      
    end
  end
end