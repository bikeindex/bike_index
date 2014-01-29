module Api
  module V1
    class BikesController < ApiV1Controller
      before_filter :cors_preflight_check
      before_filter :authenticate_organization, only: [:create]
      after_filter :cors_set_access_control_headers
      caches_action :search_tags

      def search_tags
        tags = []
        Color.unscoped.commonness.each { |i| tags << i.name }
        HandlebarType.all.each { |i| tags << i.name }
        FrameMaterial.all.each  { |i| tags << i.name }
        WheelSize.unscoped.commonness.each { |i| tags << "#{i.name} wheel" }
        Manufacturer.all.each { |i| tags << i.name }
        respond_with tags, root: 'tags'
      end

      def index
        respond_with BikeSearcher.new(params).find_bikes.limit(10)
      end

      def show
        respond_with Bike.unscoped.find(params[:id])
      end

      def create
        params = de_string_params
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

      def de_string_params
        # Google app script doesn't support nested params -
        # So we're doing this.
        params[:bike] = JSON.parse params[:bike] if params[:bike].kind_of?(String)
        params[:stolen_record] = JSON.parse params[:stolen_record] if params[:stolen_record].kind_of?(String)
        params[:components] = JSON.parse params[:components] if params[:components].kind_of?(String)
        params
      end
    end

  end
end