class Admin::StolenNotificationsController < Admin::BaseController
  before_filter :find_notification, only: [:show, :resend]

  def index
    stolen_notifications = StolenNotification.order('created_at desc').includes(:bike)
    page = params[:page] || 1
    per_page = params[:per_page] || 100
    @stolen_notifications = stolen_notifications.page(page).per(per_page)
  end

  def resend
    if @stolen_notification.send_dates_parsed.count == 0 or params[:pretty_please]
      EmailStolenNotificationWorker.perform_async(@stolen_notification.id)
      flash[:success] = 'Notification resent!'
      redirect_to admin_stolen_notifications_url
    else
      flash[:success] = 'Notification has already been resent! If you actually want to resend, click the button on this page'
      redirect_to admin_stolen_notification_url(@stolen_notification)
    end
  end

  def show
    @bike = @stolen_notification.bike
    @stolen_notification = @stolen_notification.decorate
  end

  def find_notification
    @stolen_notification = StolenNotification.find(params[:id])
  end
end
