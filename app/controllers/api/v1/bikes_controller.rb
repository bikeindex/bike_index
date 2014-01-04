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
        raise StandardError unless params[:bike].present?
        params[:bike][:creation_organization_id] = @organization.id
        @b_param = BParam.create(creator_id: @organization.auto_user.id, params: params)
        if params[:keys_included]
          bike = BikeCreator.new(@b_param).create_bike
        else
          # bike = BikeCreator.new(@b_param).create_bike_without_foreign_keys
          @b_param.update_attributes(bike_errors: {foreign_keys: "not associated"}) 
        end
        unless @b_param.errors.blank? && @b_param.bike_errors.blank? && bike.present? && bike.errors.blank?
          email_admin = Feedback.new(email: 'contact@bikeindex.org', name: 'Error mailer', title: 'API Bike Creation error!', body: params)
          email_admin.body = bike.errors.full_messages.to_sentence if bike.present? && bike.errors.any?
          email_admin.save
        end
        render :text => '{"status": "success"}'
      end
    
      def authenticate_organization
        organization = Organization.find_by_slug(params[:organization_slug])
        if organization.access_token == params[:access_token]
          @organization = organization
        else
          raise StandardError
          # At some point we'll want to rescue these errors.
          # For now, throw an error and so we get an airbrake notification anytime this happens...
          # Since we probably did something wrong.
          # Because who the hell is posting to our API without instruction?
          # No-one. That's who. Since there is no documentation.
        end
      end
    end

  end
end
# associated