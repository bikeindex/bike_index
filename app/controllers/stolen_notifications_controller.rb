class StolenNotificationsController < ApplicationController
  before_filter :authenticate_user

  def new
    @stolen_notification = StolenNotification.new
  end

  def create
    @stolen_notification = StolenNotification.new(params[:stolen_notification])
    @stolen_notification.sender = current_user
    @bike = @stolen_notification.bike
    if @stolen_notification.save
      flash[:notice] = "Thanks for looking out!" 
      redirect_to @bike
    else
      flash[:notice] = "Crap! We couldn't send your notification. Please try again."
      render @bike
    end
  end

end
