class UserEmbedsController < ApplicationController
  skip_before_filter :set_x_frame_options_header
  layout 'embed_user_layout'

  def show
    @text = params[:text]
    user = User.find_by_username(params[:id])
    bikes = user.bikes if user.present?
    unless user && user.show_bikes? && bikes.present?
      @text = 'Most Recent Indexed Bikes'
      bikes = Bike.where('thumb_path IS NOT NULL').limit(5)
    end
    @bikes = BikeDecorator.decorate_collection(bikes)
  end
end
