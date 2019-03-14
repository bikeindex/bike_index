module Api
  module V1
    class BikesController < ApiV1Controller
      before_filter :cors_preflight_check
      before_filter :authenticate_organization, only: [:create, :stolen_ids]
      skip_before_filter :verify_authenticity_token
      after_filter :cors_set_access_control_headers
      # caches_action :search_tags
      # serialization_scope nil

      def search_tags
        tags = []
        Color.unscoped.commonness.each { |i| tags << i.name }
        HandlebarType::NAMES.values.each { |name| tags << name }
        FrameMaterial::NAMES.values.each  { |name| tags << name }
        WheelSize.unscoped.commonness.each { |i| tags << "#{i.name} wheel" }
        Manufacturer.all.each { |i| tags << i.name }
        CycleType::NAMES.values.each { |name| tags << name }
        respond_with tags, root: 'tags'
      end

      def index
        if params[:proximity] == 'ip'
          if Rails.env == 'production'
            params[:proximity] = request.env["HTTP_X_FORWARDED_FOR"].split(',')[0]
          else
            params[:proximity] = request.remote_ip
          end
        end
        if params[:ip_test]
          info = { ip: params[:proximity], location: Geocoder.search(params[:proximity]) }
          respond_with info and return
        end
        respond_with BikeSearcher.new(params).find_bikes.limit(20)
      end

      def stolen_ids
        stolen = StolenRecord.where(approved: true)
        if params[:proximity].present?
          radius = 50
          radius = params[:proximity_radius] if params[:proximity_radius].present? && params[:proximity_radius].strip.length > 0
          box = Geocoder::Calculations.bounding_box(Geohelper.formatted_address(params[:proximity]), radius)
          stolen = stolen.within_bounding_box(box)
        end
        if params[:updated_since]
          since_date = Time.at(params[:updated_since].to_i).utc.to_datetime
          stolen = stolen.where("updated_at >= ?", since_date)
        end
        render json: { bikes: stolen.pluck(:bike_id) }
      end

      def close_serials
        response = {bikes: []}
        response = BikeSearcher.new(params).close_serials.limit(20) if params[:serial].present?
        respond_with response
      end

      def show
        render json: Bike.unscoped.find(params[:id]), serializer: SingleBikeSerializer
      end

      def create
        params = de_string_params
        raise StandardError unless params[:bike].present?
        params[:bike][:creation_organization_id] = @organization.id
        @b_param = BParam.create(creator_id: @organization.auto_user.id, params: permitted_b_params, origin: 'api_v1')
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
        organization = Organization.friendly_find(params[:organization_slug])
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

      def permitted_b_params
        params.as_json
      end
    end
  end
end
