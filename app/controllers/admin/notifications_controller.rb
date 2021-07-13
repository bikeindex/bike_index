class Admin::NotificationsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @notifications = matching_notifications.reorder("notifications.#{sort_column} #{sort_direction}")
      .includes(:bike, :notifiable, :user)
      .page(page).per(per_page)
  end

  helper_method :matching_notifications, :special_kind_scopes

  private

  def sortable_columns
    %w[created_at updated_at kind user_id bike_id]
  end

  def earliest_period_date
    Time.at(1593464621)
  end

  def special_kind_scopes
    %w[donation theft_alert impound_claim customer_contact]
  end

  def permitted_scopes
    Notification.kinds + special_kind_scopes
  end

  def matching_notifications
    notifications = Notification
    if permitted_scopes.include?(params[:search_kind])
      @kind = params[:search_kind]
      notifications = notifications.send(@kind)
    else
      @kind = "all"
    end
    if ParamsNormalizer.boolean(params[:search_with_bike])
      @with_bike = true
      notifications = notifications.with_bike
    end
    if ParamsNormalizer.boolean(params[:search_undelivered])
      @undelivered = true
      notifications = notifications.undelivered
    end
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      notifications = notifications.where(user_id: @user.id) if @user.present?
    end
    # I don't know why this isn't working - see also user_alerts - ignoring and forcing created_at
    # @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    # notifications.where(@time_range_colum => @time_range)
    notifications.where(created_at: @time_range)
  end
end
