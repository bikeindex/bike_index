class UserEmbedsController < ApplicationController
  layout 'embed_user_layout'

  def show
    @text = params[:text]
    user = User.find_by_username(params[:id])
    bikes = Bike.find(user.bikes) if user.present?
    unless bikes.any? # takes care of both user not found, and user with no bikes
      @text = "Most Recent Indexed Bikes"
      bikes = Bike.where("thumb_path IS NOT NULL").limit(5)
    end    
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

end