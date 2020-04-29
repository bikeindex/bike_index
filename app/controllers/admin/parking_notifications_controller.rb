class Admin::ParkingNotificationsController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @parking_notifications = matching_parking_notifications.includes(:user, :organization, :bike)
      .order(sort_column + " " + sort_direction)
      .page(page).per(per_page)
  end

  helper_method :matching_parking_notifications

  protected

  def sortable_columns
    %w[created_at organization_id kind updated_at user_id resolved_at]
  end

  def matching_parking_notifications
    return @matching_parking_notifications if defined?(@matching_parking_notifications)
    parking_notifications = ParkingNotification
    parking_notifications.resolved if sort_column == "resolved_at"
    if ParkingNotification.statuses.include?(params[:search_status])
      @search_status = params[:search_status]
      parking_notifications = parking_notifications.where(status: @search_status)
    else
      @search_status = "all"
    end
    parking_notifications = parking_notifications.where(organization_id: current_organization.id) if current_organization.present?
    @matching_parking_notifications = parking_notifications.where(created_at: @time_range)
  end
end
