=begin
*****************************************************************
* File: app/controllers/ownerships_controller.rb 
* Name: Class OwnershipsController 
* Set some methods to deal with ownership
*****************************************************************
=end

class OwnershipsController < ApplicationController

  # The passed filters will be appended to the filter_chain and will execute before the action on this controller is performed
  before_filter :find_ownership
  before_filter -> { authenticate_user(no_user_flash_msg) }

=begin
  Name: show 
  Params: Pass as parameter the ownership bike and the current user logged
  Explication: Method used to identify the bicycle with their respective owner.
  Return: redirect to edit bike or redirect to bike url   
=end
  def show
    # Create a method with the objective of showing the bicycles which were not identified the owner.
    bike = Bike.unscoped.find(@ownership.bike_id)
    if @ownership.can_be_claimed_by(current_user)
      if @ownership.current
        @ownership.mark_claimed
        flash[:notice] = "Looks like this is your #{bike.type}! Good work, you just claimed it."
        redirect_to edit_bike_url(bike)
      else
        flash[:error] = "That used to be your #{bike.type} but isn't anymore! Contact us if this doesn't make sense."
        redirect_to bike_url(bike)
      end
    else
      flash[:error] = "That doesn't appear to be your #{bike.type}! Contact us if this doesn't make sense."
      redirect_to bike_url(bike)
    end
  end

=begin
  Name: no_user_flash_msg
  Params: none
  Explication: Method used to configure the type message displayed to user.
  Return: 4 types possible messages: "#{@ownership.bike.type}" or "The owner of this #{type} already has an account on the Bike Index. Sign in to claim it!" or "Create an account to claim that #{type}! Use the email you used when registering it and you will be able to claim it after signing up!" or "Sorry, unable to find that bike".   
=end
  def no_user_flash_msg
    # Condition to see if the owner and their respective bike are present.
    if @ownership && @ownership.bike.present?
      type = "#{@ownership.bike.type}"
      if @ownership.user.present?
        "The owner of this #{type} already has an account on the Bike Index. Sign in to claim it!"
      else
        "Create an account to claim that #{type}! Use the email you used when registering it and you will be able to claim it after signing up!"
      end
    else
      "Sorry, unable to find that bike"
    end
  end

  private

=begin
  Name: find_ownership
  Params: pass the specific parameter of the ownership 
  Explication: method used to search ownership bike
  Return: @ownership   
=end
  def find_ownership
    @ownership = Ownership.find(params[:id])
  end

end
