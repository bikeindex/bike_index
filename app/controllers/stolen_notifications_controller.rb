class StolenNotificationsController < ApplicationController
  before_filter :authenticate_user

  def new
    @stolen_notification = StolenNotification.new
  end

  def create
    @stolen_notification = StolenNotification.new(permitted_parameters)
    @stolen_notification.sender = current_user
    @bike = @stolen_notification.bike
    if !@bike.contact_owner?(current_user)
      flash[:error] = "You don't have permission to send that notification! Please contact support@bikeindex.org"
      redirect_to @bike
    elsif @stolen_notification.save
      flash[:success] = 'Thanks for looking out!'
      redirect_to @bike
    else
      flash[:error] = "Crap! We couldn't send your notification. Please try again."
      render @bike
    end
  end

  private

  def permitted_parameters
    params.require(:stolen_notification)
          .permit(:subject, :reference_url, :message, :bike_id, :receiver_email, :send_dates, :application_id)
  end
end
