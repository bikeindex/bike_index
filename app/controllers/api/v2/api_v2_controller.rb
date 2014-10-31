module Api
  module V2
    class ApiV2Controller < ApplicationController
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers
      respond_to :json

      private
      def current_resource_owner
        User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
      end
      
    end
  end
end