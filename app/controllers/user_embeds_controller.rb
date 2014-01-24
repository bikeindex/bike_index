class UserEmbedsController < ApplicationController
  layout 'embed_user_layout'

  def show
    @text = params[:text]
    user = User.find_by_username(params[:id])
    if user.present?
      bikes = Bike.find(user.bikes)
    else
      @text = "Most Recent Indexed Bikes"
      bikes = Bike.where("thumb_path IS NOT NULL").limit(5)
    end    
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

end