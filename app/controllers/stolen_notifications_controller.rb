=begin
*********************************************************************
* File: app/controllers/stolenNotifications_controller.rb 
* Name: Class StolenNotificationsController 
* Set some methods to deal with the notifications received of stolens 
*********************************************************************
=end

class StolenNotificationsController < ApplicationController
  before_filter :authenticate_user

  def new
    @stolenNotification = StolenNotification.new
  end

  def create
    @stolenNotification = StolenNotification.new(params[:stolenNotification])
    @stolenNotification.sender = current_user
    @bike = @stolenNotification.bike
    if @stolenNotification.save
      flash[:notice] = "Thanks for looking out!" 
      redirect_to @bike
    else
      flash[:notice] = "Crap! We couldn't send your notification. Please try again."
      render @bike
    end
  end

end
