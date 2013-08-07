module Api
  module V1
    class UsersController < ApiV1Controller
      before_filter :bust_cache!, only: [:current]
      
      def current
        if current_user.present?
          respond_with current_user
        else
          respond_with user_present: false
        end
      end
    end
  end
end 