module Organized
  class ParkingNotificationsController < Organized::BaseController
    include Rails::Pagination
    include SortableTable
    DEFAULT_PER_PAGE = 200
    before_action :ensure_access_to_parking_notifications!, only: %i[index create]
    before_action :set_period, only: [:index]
    before_action :set_failed_and_repeated_ivars

    def index
      @search_bounding_box = search_bounding_box
      @per_page = params[:per_page]
      @per_page = DEFAULT_PER_PAGE if @per_page.blank? || @per_page.to_i > ParkingNotification::MAX_PER_PAGE
      @page_data = {
        google_maps_key: ENV["GOOGLE_MAPS"],
        per_page: @per_page,
        default_location: @search_bounding_box.blank?,
        map_center_lat: map_center(@search_bounding_box).first,
        map_center_lng: map_center(@search_bounding_box).last
      }

      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      # These are set here because we render them in HTML
      @search_status = if params[:search_status] == "all"
        "all"
      else
        ParkingNotification.statuses.include?(params[:search_status]) ? params[:search_status] : "current"
      end
      @search_unregistered = %w[only_unregistered not_unregistered].include?(params[:search_unregistered]) ? params[:search_unregistered] : "all"

      headers["Vary"] = "Accept" # When hitting back button, tell browser not use the json response
      respond_to do |format|
        format.html
        format.json do
          @page = params[:page] || 1
          records = matching_parking_notifications.reorder("parking_notifications.#{sort_column} #{sort_direction}")
            .includes(:user, :bike, :impound_record)
            .page(@page).per(@per_page)
          set_pagination_headers(records, @page, @per_page) # Can't use api-pagination, because it blocks overriding max_per_page

          render json: records,
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

    def sortable_columns
      %w[created_at updated_at user_id kind]
    end

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
      if @search_bounding_box.present?
        notifications = notifications.search_bounding_box(*@search_bounding_box)
      end
      if params[:user_id].present?
        notifications = notifications.where(user_id: params[:user_id])
      end
      if ParkingNotification.kinds.include?(params[:search_kind]).present?
        notifications = notifications.where(kind: params[:search_kind])
      end
      if @search_unregistered == "only_unregistered"
        notifications = notifications.unregistered_bike
      elsif @search_unregistered == "not_unregistered"
        notifications = notifications.not_unregistered_bike
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
        .permit(:message, :internal_notes, :bike_id, :kind, :is_repeat, :image, :latitude, :longitude,
          :accuracy, :street, :city, :zipcode, :state_id, :country_id)
        .merge(user_id: current_user.id, organization_id: current_organization.id,
               use_entered_address: use_entered_address)
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
      notifications_failed_resolved_ids = selected_notifications.resolved.pluck(:id)
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
      session[:notifications_repeated_ids] = @notifications_repeated.pluck(:id)
      # If the notification was repeated, it can't also be failed (relevant when marking resolved)
      session[:notifications_failed_resolved_ids] = notifications_failed_resolved_ids - session[:notifications_repeated_ids]
      @notifications_failed_resolved ||= ParkingNotification.where(id: session[:notifications_failed_resolved_ids])
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
      nil
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

    def search_bounding_box
      return nil unless params[:search_southwest_coords].present? && params[:search_northeast_coords].present?
      [params[:search_southwest_coords].split(","), params[:search_northeast_coords].split(",")].flatten.map(&:to_f)
    end

    def map_center(bounding_box)
      return current_organization.map_focus_coordinates.values unless bounding_box.present?
      lat_dif = bounding_box[0] - bounding_box[2]
      lng_dif = bounding_box[1] - bounding_box[3]
      [bounding_box[0] + lat_dif, bounding_box[1] + lng_dif]
    end

    # Pulling this out of api-pagination gem because the gem doesn't allow overriding the max per
    def set_pagination_headers(collection, page, per_page)
      url = request.base_url + request.path_info
      pages = ApiPagination.pages_from(collection)
      links = []

      pages.each do |k, v|
        new_params = request.query_parameters.merge(page: v)
        links << %(<#{url}?#{new_params.to_param}>; rel="#{k}")
      end

      headers["Page"] = page
      headers["Link"] = links.join(", ") unless links.empty?
      headers["Per-Page"] = per_page.to_s
      headers["Total"] = collection.total_count.to_s
    end
  end
end
