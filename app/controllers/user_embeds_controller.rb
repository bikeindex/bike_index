class UserEmbedsController < ApplicationController
  before_action :allow_x_frame
  layout "embed_user_layout"

  def show
    @text = params[:text]
    user = User.find_by_username(params[:id])
    bikes = user.bikes if user.present?
    unless user&.show_bikes? && bikes.present?
      @text = "Most Recent Indexed Bikes"
      bikes = Bike.where("thumb_path IS NOT NULL").limit(5)
    end
    @bikes = bikes
  end
end
