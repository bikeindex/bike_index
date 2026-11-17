class StolenNotificationsController < ApplicationController
  before_action :authenticate_user

  def new
    @stolen_notification = StolenNotification.new
  end

  def create
    @stolen_notification = StolenNotification.new(permitted_parameters)
    @stolen_notification.sender = current_user
    @bike = Bike.find(@stolen_notification.bike_id)
    if !@bike.contact_owner?(current_user)
      flash[:error] = translation(:unauthorized)
    elsif @stolen_notification.save
      flash[:success] = translation(:thanks)
    else
      flash[:error] = translation(:failure)
    end
    redirect_to @bike
  end

  private

  def permitted_parameters
    params.require(:stolen_notification)
      .permit(:subject, :reference_url, :message, :bike_id)
  end
end
