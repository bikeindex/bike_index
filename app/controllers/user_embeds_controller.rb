=begin
*****************************************************************
* File: app/controllers/users_embeds_controller.rb 
* Name: Class UsersEmbedsController 
* Set some methods to manager userEmbeds
*****************************************************************
=end

class UserEmbedsController < ApplicationController

  # The passed filters will be appended to the filter_chain and will execute before the action on this controller is performed
  skip_before_filter :set_x_frame_options_header
  layout 'embed_user_layout'

=begin
  Name: show
  Explication: method to identify user and to show the most new bike added.  
  Params: user's id and text to show message: "most recent indexed bike" 
  Return: most recent indexed bike 
=end
  def show
    @text = params[:text]
    user = User.find_by_username(params[:id])
    if user.present?
      bikes = user.bikes
    # Method to verify if user isn't logged, otherwise indexed a new bike    
    unless user && user.show_bikes? && bikes.present?
      @text = "Most Recent Indexed Bikes"
      bikes = Bike.where("thumb_path IS NOT NULL").limit(5)
    end
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

end