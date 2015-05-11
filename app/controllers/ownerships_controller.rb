class OwnershipsController < ApplicationController
  before_filter :find_ownership
  before_filter -> { authenticate_user(no_user_flash_msg) }

  def show
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

  def no_user_flash_msg
    type = "#{@ownership.bike.type}"
    if @ownership.user.present?
      "The owner of this #{type} already has an account on the Bike Index. Sign in to claim it!"
    else
      "Create an account to claim that #{type}! Use the email you used when registering it and you will be able to claim it after signing up!"
    end
  end

  private

  def find_ownership
    @ownership = Ownership.find(params[:id])
  end

end
