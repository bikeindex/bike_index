module Organized
  class ParkingNotificationsController < Organized::BaseController
    before_action :ensure_access_to_parking_notifications!, only: %i[index create]
    before_action :set_period, only: [:index]
    skip_before_action :set_x_frame_options_header, only: [:email]

    def index
      @page_data = {
        google_maps_key: ENV["GOOGLE_MAPS"],
        map_center_lat: current_organization.map_focus_coordinates[:latitude],
        map_center_lng: current_organization.map_focus_coordinates[:longitude],
      }

      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      respond_to do |format|
        format.html
        format.json do
          page = params[:page] || 1
          per_page = params[:per_page] || 100
          # TODO: add sortable here
          records = matching_parking_notifications.reorder(created_at: :desc)
          render json: records.page(page).per(per_page),
                 root: "parking_notifications",
                 each_serializer: ParkingNotificationSerializer
        end
      end
    end

    def show
      @parking_notification = parking_notifications.find(params[:id])
      related_ids = [@parking_notification, @parking_notification.initial_record_id].compact
      @related_notifications = parking_notifications.where(id: related_ids)
                                .or(parking_notifications.where(initial_record_id: related_ids))
                                .where.not(id: @parking_notification.id)
      @bike = @parking_notification.bike
    end

    def email
      @organization = current_organization
      @email_preview = true
      @parking_notification = parking_notifications.find(params[:id])
      @bike = @parking_notification.bike
      render template: "/organized_mailer/parking_notification", layout: "email"
    end

    def create
      @parking_notification = ParkingNotification.new(permitted_parameters)
      if @parking_notification.save
        flash[:success] = translation(:successfully_created, bike_type: @parking_notification.bike.type)
      else
        flash[:error] = translation(:unable_to_create, errors: @parking_notification.errors.full_messages.to_sentence)
      end
       redirect_back(fallback_location: organization_parking_notifications_path(organization_id: current_organization.to_param))
    end

    helper_method :matching_parking_notifications, :search_params_present?

    private

    def parking_notifications
      current_organization.parking_notifications
    end

    def matching_parking_notifications
      return @matching_parking_notifications if defined?(@matching_parking_notifications)
      notifications = parking_notifications
      if params[:search_bike_id].present?
        notifications = notifications.where(bike_id: params[:search_bike_id])
      end
      if bike_search_params_present?
        notifications = notifications.where(bike_id: search_organization_bikes.pluck(:id))
      end
      @matching_parking_notifications = notifications.where(created_at: @time_range)
    end

    def search_params_present?
      # Eventually, will check period select, etc
      (params.keys & %w[search_bike_id]).any?
    end

    def permitted_parameters
      use_entered_address = ParamsNormalizer.boolean(params.dig(:parking_notification, :use_entered_address))
      params.require(:parking_notification)
            .permit(:message, :internal_notes, :bike_id, :kind, :is_repeat, :latitude, :longitude, :accuracy,
                    :street, :city, :zipcode, :state_id, :country_id)
            .merge(user_id: current_user.id, organization_id: current_organization.id, use_entered_address: use_entered_address)
    end

    def ensure_access_to_parking_notifications!
      return true if current_organization.enabled?("parking_notifications")
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      return
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:email].present?
    end

    def search_organization_bikes
      bikes = current_organization.parking_notification_bikes
      bikes = bikes.search(@interpreted_params)
      bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
      bikes
    end
  end
end
