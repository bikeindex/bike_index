module Api
  module V1
    class BikesController < ApiV1Controller
      before_filter :cors_preflight_check
      before_filter :authenticate_organization, only: [:create]
      after_filter :cors_set_access_control_headers


      def index
        respond_with BikeSearcher.new(params).find_bikes.limit(10)
      end

      def show
        respond_with Bike.unscoped.find(params[:id])
      end

      def create
        raise StandardError unless params[:bike].present?
        params[:bike][:creation_organization_id] = @organization.id
        @b_param = BParam.create(creator_id: @organization.auto_user.id, params: params)
        bike = BikeCreator.new(@b_param).create_bike
        if @b_param.errors.blank? && @b_param.bike_errors.blank? && bike.present? && bike.errors.blank?
          render json: {bike: { web_url: bike_url(bike), api_url: api_v1_bike_url(bike)}} and return
        else
          if bike.present?
            e = bike.errors.full_messages.to_sentence
          else
            e = @b_param.errors.full_messages.to_sentence
          end
          Feedback.create(email: 'contact@bikeindex.org', name: 'Error mailer', title: 'API Bike Creation error!', body: e)
          render json: e, status: :unprocessable_entity and return
        end
        
      end
    
      def authenticate_organization
        organization = Organization.find_by_slug(params[:organization_slug])
        if organization.present? && organization.access_token == params[:access_token]
          @organization = organization
        else
          render json: "Not authorized", status: :unauthorized and return
        end
      end
    end

  end
end