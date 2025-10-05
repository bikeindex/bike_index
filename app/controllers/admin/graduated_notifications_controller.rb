class Admin::GraduatedNotificationsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @graduated_notifications = pagy(matching_graduated_notifications.includes(:user, :organization, :bike)
      .order(sort_column + " " + sort_direction), limit: @per_page, page: permitted_page)
  end

  helper_method :matching_graduated_notifications

  protected

  def sortable_columns
    %w[created_at organization_id kind updated_at user_id resolved_at]
  end

  def matching_graduated_notifications
    return @matching_graduated_notifications if defined?(@matching_graduated_notifications)

    graduated_notifications = GraduatedNotification
    if GraduatedNotification.statuses.include?(params[:search_status])
      @search_status = params[:search_status]
      graduated_notifications = graduated_notifications.where(status: @search_status)
    else
      @search_status = "all"
    end
    if params[:search_bike_id].present?
      @bike = Bike.unscoped.friendly_find(params[:search_bike_id])
      graduated_notifications = graduated_notifications.where(bike_id: params[:search_bike_id])
    end
    graduated_notifications = graduated_notifications.marked_remaining if sort_column == "marked_remaining_at"
    graduated_notifications = graduated_notifications.where(organization_id: current_organization.id) if current_organization.present?
    @matching_graduated_notifications = graduated_notifications.where(created_at: @time_range)
  end
end
