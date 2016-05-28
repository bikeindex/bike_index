=begin
*********************************************************************
* File: app/controllers/stolenNotifications_controller.rb 
* Name: Class StolenNotificationsController 
* Set some methods to deal with the notifications received of stolens 
*********************************************************************
=end

class StolenNotificationsController < ApplicationController
  before_filter :authenticate_user

=begin
  Name: new
  Explication: method used to instance a new stolen notification about bike 
  Params: none 
  Return: a new instance of stolen notification 
=end
  def new
    @stolenNotification = StolenNotification.new
    assert_object_is_not_null(@stolenNotification)
    assert_message(@stolenNotification.kind_of?(StolenNotification))
    return @stolenNotification
  end

=begin
  Name: create
  Explication: method used to create the new instance about stolen notification bike 
  Params: stolen notification about bike 
  Return: stolen notification bike or redirect to @bike or render @bike
=end
  def create
    @stolenNotification = StolenNotification.new(params[:stolenNotification])
    assert_message(@stolenNotification.kind_of?(StolenNotification))
    assert_object_is_not_null(@stolenNotification)
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
