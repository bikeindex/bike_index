module Organized
  class ParkingNotificationsController < Organized::BaseController
    before_action :ensure_access_to_parking_notifications!, only: %i[index create]
    before_action :set_period, only: [:index]
    before_action :set_failed_and_repeated_ivars

    def index
      @page_data = {
        google_maps_key: ENV["GOOGLE_MAPS"],
        map_center_lat: current_organization.map_focus_coordinates[:latitude],
        map_center_lng: current_organization.map_focus_coordinates[:longitude],
      }

      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
      if params[:search_status] == "all"
        @search_status = "all"
      else
        @search_status = ParkingNotification.statuses.include?(params[:search_status]) ? params[:search_status] : "current"
      end

      respond_to do |format|
        format.html
        format.json do
          page = params[:page] || 1
          per_page = params[:per_page] || 100
          # TODO: add sortable here
          records = matching_parking_notifications.reorder(created_at: :desc).includes(:user, :bike, :impound_record)
          render json: records.page(page).per(per_page),
                 root: "parking_notifications",
                 each_serializer: ParkingNotificationSerializer
        end
      end
    end

    def show
      @parking_notification = parking_notifications.find(params[:id])
      @bike = @parking_notification.bike
    end

    def create
      if params[:kind].present? # It's a send_additional kind
        create_and_send_repeats(params[:kind], params[:ids].as_json)
      else
        @parking_notification = ParkingNotification.new(permitted_parameters)
        if @parking_notification.save
          flash[:success] = translation(:successfully_created, bike_type: @parking_notification.bike.type)
        else
          flash[:error] = translation(:unable_to_create, errors: @parking_notification.errors.full_messages.to_sentence)
        end
      end
      if @redirect_location.present?
        redirect_to @redirect_location
      else
        redirect_back(fallback_location: organization_parking_notifications_path(organization_id: current_organization.to_param))
      end
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
      unless @search_status == "all"
        notifications = parking_notifications.where(status: @search_status)
      end
      if params[:search_bike_id].present?
        notifications = notifications.where(bike_id: params[:search_bike_id])
      end
      if bike_search_params_present?
        bikes = notifications.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:search_email]) if params[:search_email].present?
        notifications = notifications.where(bike_id: bikes.pluck(:id))
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

    def create_and_send_repeats(kind, ids)
      ids_array = ids if ids.is_a?(Array)
      ids_array = ids.keys if ids.is_a?(Hash) # parameters submitted look like this ids: { "12" => "12" }
      ids_array ||= ids.to_s.split(",")
      ids_array = ids_array.map { |id| id.strip.to_i }.reject(&:blank?)
      if ids_array.empty?
        flash[:error] = "No notifications selected!"
        return true
      end

      selected_notifications = parking_notifications.where(id: ids_array)
      # We can't update already resolved notifications - so add them to an ivar for displaying
      @notifications_failed_resolved = selected_notifications.resolved
      success_ids = []
      ids_repeated = []

      selected_notifications.active.each do |parking_notification|
        target_notification = parking_notification.current_associated_notification
        # Don't repeat notifications already sent, or previous to ones already targeted
        next if (ids_repeated + success_ids).include?(target_notification.id)
        ids_repeated << target_notification.id
        new_notification = target_notification.retrieve_or_repeat_notification!(kind: kind, user_id: current_user.id)
        success_ids << new_notification.id
      end
      @notifications_repeated = ParkingNotification.where(id: ids_repeated)
      # If sending only one repeat notification, redirect to that notification
      if ids_array.count == 1 && success_ids.count == 1
        @redirect_location = organization_parking_notification_path(success_ids.first, organization_id: current_organization.to_param)
      end
      session[:notifications_failed_resolved_ids] = @notifications_failed_resolved.pluck(:id)
      session[:notifications_repeated_ids] = @notifications_repeated.pluck(:id)
      session[:repeated_kind] = kind
      # I don't think there will be a failure without error, retrieve_or_repeat_notification! should throw an error
      # rescuing makes it difficult to diagnose the problem, so we're just going to silently fail. sry
      # flash[:error] = "Unable to send notifications for #{(ids - success_ids).map { |i| "##{i}" }.join(", ")}"
    end

    def set_failed_and_repeated_ivars
      return true unless session[:repeated_kind].present?
      @repeated_kind = session.delete(:repeated_kind)
      notifications_failed_resolved_ids = session.delete(:notifications_failed_resolved_ids)
      notifications_repeated_ids = session.delete(:notifications_repeated_ids)
      if notifications_failed_resolved_ids.present?
        @notifications_failed_resolved = parking_notifications.where(id: notifications_failed_resolved_ids)
                                                              .includes(:user, :bike, :impound_record)
      end
      if notifications_repeated_ids.present?
        @notifications_repeated = parking_notifications.where(id: notifications_repeated_ids)
                                                       .includes(:user, :bike, :impound_record)
      end
    end

    def ensure_access_to_parking_notifications!
      return true if current_organization.enabled?("parking_notifications")
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      return
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:search_email].present?
    end

    def search_organization_bikes
      bikes = current_organization.parking_notification_bikes
      bikes = bikes.search(@interpreted_params)
      bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
      bikes
    end
  end
end
