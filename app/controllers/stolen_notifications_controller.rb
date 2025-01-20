class StolenNotificationsController < ApplicationController
  before_action :authenticate_user

  def new
    @stolen_notification = StolenNotification.new
  end

  def create
    @stolen_notification = StolenNotification.new(permitted_parameters)
    @stolen_notification.sender = current_user
    @bike = @stolen_notification.bike
    if !@bike.contact_owner?(current_user)
      flash[:error] = translation_with_args(:unauthorized)
      redirect_to @bike
    elsif @stolen_notification.save
      flash[:success] = translation_with_args(:thanks)
      redirect_to @bike
    else
      flash[:error] = translation_with_args(:failure)
      render @bike
    end
  end

  private

  def permitted_parameters
    params.require(:stolen_notification)
      .permit(:subject, :reference_url, :message, :bike_id)
  end
end
