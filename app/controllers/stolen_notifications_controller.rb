class StolenNotificationsController < ApplicationController
  before_filter :authenticate_user

  def new
    @stolen_notification = StolenNotification.new
  end

  def create
    @stolen_notification = StolenNotification.new(permitted_parameters)
    @stolen_notification.sender = current_user
    @bike = @stolen_notification.bike
    if @stolen_notification.save
      flash[:success] = 'Thanks for looking out!'
      redirect_to @bike
    else
      flash[:error] = "Crap! We couldn't send your notification. Please try again."
      render @bike
    end
  end

  private

  def permitted_parameters
    params.require(:stolen_notification).permit(StolenNotification.old_attr_accessible)
  end
end
