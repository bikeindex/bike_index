class Admin::NotificationsController < Admin::BaseController
  include SortableTable

  def index
    params[:page] || 1
    @per_page = permitted_per_page(default: 50)
    @pagy, @notifications = pagy(matching_notifications.reorder("notifications.#{sort_column} #{sort_direction}")
      .includes(:bike, :notifiable, :user), limit: @per_page, page: permitted_page)
    @render_kind_counts = Binxtils::InputNormalizer.boolean(params[:search_kind_counts])
  end

  helper_method :matching_notifications, :special_kind_scopes

  private

  def sortable_columns
    %w[created_at updated_at kind user_id bike_id]
  end

  def earliest_period_date
    Time.at(1401122000)
  end

  def special_kind_scopes
    %w[donation theft_alert impound_claim customer_contact admin]
  end

  def permitted_scopes
    Notification.kinds + special_kind_scopes
  end

  def matching_notifications
    notifications = Notification
    if permitted_scopes.include?(params[:search_kind])
      @kind = params[:search_kind]
      notifications = notifications.public_send(@kind)
    else
      @kind = "all"
    end
    if Binxtils::InputNormalizer.boolean(params[:search_with_bike])
      @with_bike = true
      notifications = notifications.with_bike
    end
    if Binxtils::InputNormalizer.boolean(params[:search_undelivered])
      @undelivered = true
      notifications = notifications.not_delivery_success
    end
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      notifications = notifications.notifications_sent_or_received_by(@user.id) if @user.present?
    end
    if params[:search_bike_id].present?
      @bike = Bike.unscoped.friendly_find(params[:search_bike_id])
      notifications = notifications.where(bike_id: @bike.id) if @bike.present?
    end
    if params[:query].present?
      notifications = notifications.search_message_channel_target(params[:query])
    end
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    notifications.where(@time_range_column => @time_range)
  end
end
