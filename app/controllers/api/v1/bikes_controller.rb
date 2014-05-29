module Api
  module V1
    class BikesController < ApiV1Controller
      before_filter :cors_preflight_check
      before_filter :authenticate_organization, only: [:create, :stolen_ids, :send_notification_email]
      after_filter :cors_set_access_control_headers
      caches_action :search_tags
      serialization_scope nil

      def search_tags
        tags = []
        Color.unscoped.commonness.each { |i| tags << i.name }
        HandlebarType.all.each { |i| tags << i.name }
        FrameMaterial.all.each  { |i| tags << i.name }
        WheelSize.unscoped.commonness.each { |i| tags << "#{i.name} wheel" }
        Manufacturer.all.each { |i| tags << i.name }
        CycleType.all.each { |i| tags << i.name }
        respond_with tags, root: 'tags'
      end

      def index
        respond_with BikeSearcher.new(params).find_bikes.limit(20)
      end

      def stolen_ids
        stolen = StolenRecord.where(approved: true)
        if params[:proximity].present?
          radius = 500
          radius = params[:proximity_radius] if params[:proximity_radius].present? && params[:proximity_radius].strip.length > 0
          stolen = stolen.near(params[:proximity], radius)
        end
        if params[:updated_since]
          since_date = params[:updated_since][/\d.*hours?.ago/i]
          if since_date.present?
            since_date = since_date.gsub(/\D/,'').to_i.hours.ago
          else
            since_date = DateTime.parse(params[:updated_since])
          end
          stolen = stolen.where("updated_at >= ?", since_date)
        end
        respond_with stolen.pluck(:bike_id)
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

      def send_notification_email
        unless @organization.slug == 'example'
          bike = Bike.find(params[:bike_id])
          if bike.current_stolen_record.present? && bike.current_stolen_record.approved
            customer_contact = CustomerContact.new(body: params[:body], title: params[:title], bike_id: bike.id)
            customer_contact.user_email = bike.email
            customer_contact.creator_id = @organization.auto_user.id
            customer_contact.creator_email = @organization.auto_user.email
            if customer_contact.save
              Resque.enqueue(AdminStolenEmailJob, @customer_contact.id)
              render json: { success: true }
            end
          end
        end
        render json: {error: "Unable to send that email, srys"}, status: :unprocessable_entity and return
        
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