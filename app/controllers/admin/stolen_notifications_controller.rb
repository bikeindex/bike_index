class Admin::StolenNotificationsController < Admin::BaseController

  def update
    stolen_notification = StolenNotification.find(params[:id])
    Resque.enqueue(StolenNotificationEmailJob, stolen_notification.id)
    flash[:notice] = "Notification resent!"
    redirect_to admin_root_url
  end

end
