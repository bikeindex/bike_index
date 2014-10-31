module Api
  module V2
    class UsersController < ApiV2Controller
      doorkeeper_for :all 

      def current
        respond_with current_resource_owner
      end
      
    end
  end
end