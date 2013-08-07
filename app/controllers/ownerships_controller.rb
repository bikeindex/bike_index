class OwnershipsController < ApplicationController
  before_filter :authenticate_user!

  def show
    ownership = Ownership.find(params[:id])
    bike = ownership.bike 
    if current_user.email == ownership.owner_email
      if ownership.current
        ownership.mark_claimed
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
end
