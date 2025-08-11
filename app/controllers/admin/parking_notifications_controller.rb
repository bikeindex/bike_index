class Admin::ParkingNotificationsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @parking_notifications = pagy(matching_parking_notifications.includes(:user, :organization, :bike)
      .order(sort_column + " " + sort_direction), limit: @per_page, page: permitted_page)
  end

  helper_method :matching_parking_notifications

  protected

  def sortable_columns
    %w[created_at organization_id kind updated_at user_id resolved_at]
  end

  def earliest_period_date
    Time.at(1580400881) # 14 days before first parking notification created
  end

  def matching_parking_notifications
    return @matching_parking_notifications if defined?(@matching_parking_notifications)
    parking_notifications = ParkingNotification
    parking_notifications.resolved if sort_column == "resolved_at"
    if ParkingNotification.statuses.include?(params[:search_status])
      @search_status = params[:search_status]
      parking_notifications = parking_notifications.where(status: @search_status)
    elsif %w[active resolved].include?(params[:search_status])
      @search_status = params[:search_status]
      parking_notifications = (@search_status == "active") ? parking_notifications.active : parking_notifications.resolved
    else
      @search_status = "all"
    end
    parking_notifications = parking_notifications.where(organization_id: current_organization.id) if current_organization.present?
    @matching_parking_notifications = parking_notifications.where(created_at: @time_range)
  end
end
