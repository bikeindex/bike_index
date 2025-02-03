class Admin::StolenNotificationsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_notification, only: [:show, :resend]

  def index
    @per_page = params[:per_page] || 100
    @pagy, @stolen_notifications = pagy(searched_stolen_notifications
      .reorder("#{sort_column} #{sort_direction}")
      .includes(:bike), limit: @per_page)
  end

  def resend
    if (@stolen_notification.send_dates_parsed.count == 0) || params[:pretty_please]
      EmailStolenNotificationWorker.perform_async(@stolen_notification.id, true)
      flash[:success] = "Notification resent!"
      redirect_to admin_stolen_notifications_url
    else
      flash[:success] = "Notification has already been resent! If you actually want to resend AGAIN, click the button on this page"
      redirect_to admin_stolen_notification_url(@stolen_notification)
    end
  end

  def show
    @bike = @stolen_notification.bike
  end

  def find_notification
    @stolen_notification = StolenNotification.find(params[:id])
  end

  helper_method :searched_stolen_notifications

  private

  def sortable_columns
    %w[created_at updated_at sender_id receiver_id bike_id]
  end

  def searched_stolen_notifications
    stolen_notifications = StolenNotification

    @time_range_column = if %w[updated_at].include?(sort_column)
      sort_column
    else
      "created_at"
    end

    stolen_notifications.where(@time_range_column => @time_range)
  end
end
