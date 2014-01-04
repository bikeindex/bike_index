module Api
  module V1
    class BikesController < ApiV1Controller
      before_filter :cors_preflight_check
      before_filter :authenticate_organization, only: [:create]
      after_filter :cors_set_access_control_headers


      def index
        respond_with BikeSearcher.new(params).find_bikes
      end

      def show
        respond_with Bike.find(params[:id])
      end

      def create
        
        b_param = BParam.create(creator_id: current_user.id, params: params)
        @bike = BikeCreator.new(@b_param).create_bike
        if @bike.errors.any?
          email_admin = Feedback.new(email: 'contact@bikeindex.org', name: 'Error mailer', title: 'API Bike Creation error!', body: params)
          email_admin.save
        end
        render :text => '{"status": "success"}'
      end
    
    private
      def authenticate_organization
        organization = Organization.find_by_slug(params[:organization])
        if organization.access_token == params[:access_token]
          @organization = organization
        end
        # At some point we'll want to rescue these errors.
        # For now, I want to get an airbrake notification anytime this happens...
        # Because, who the hell is getting here without instruction?
      end

    end
  end
end