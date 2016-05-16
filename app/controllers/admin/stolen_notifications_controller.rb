class Admin::StolenNotificationsController < Admin::BaseController
  before_filter :find_notification, only: [:show, :resend]

  def index
    stolenNotifications = StolenNotification.order("created_at desc").includes(:bike)
    page = params[:page] || 1
    perPage = params[:perPage] || 100
    @stolenNotifications = stolenNotifications.page(page).per(perPage)
  end

  def resend
    if @stolenNotification.send_dates.count == 0 or params[:pretty_please]
      EmailStolenNotificationWorker.perform_async(@stolenNotification.id)
      flash[:notice] = "Notification resent!"
      redirect_to admin_stolenNotifications_url
    else
      flash[:notice] = "Notification has already been resent! If you actually want to resend, click the button on this page"
      redirect_to admin_stolenNotification_url(@stolenNotification)
    end
  end

  def show
    @bike = @stolenNotification.bike
    @stolenNotification = @stolenNotification.decorate
  end

  def find_notification
    @stolenNotification = StolenNotification.find(params[:id])
  end

end