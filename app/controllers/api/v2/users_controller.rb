module Api
  module V2
    class UsersController < ApiV2Controller
      before_filter :authenticate_current_resource_owner!

      def current
        respond_with current_resource_owner.api_v2_scoped
      end

      def access_scope
        if doorkeeper_token
          scope = { scope: 'Authenticated through OAuth', oauth: doorkeeper_token }
        elsif current_user.present?
          scope = { scope: 'Authenticated through the Bike Index (NOT through OAuth)'}
        end
        respond_with scope
      end
      
    end
  end
end