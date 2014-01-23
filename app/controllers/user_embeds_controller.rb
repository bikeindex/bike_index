class UserEmbedsController < ApplicationController
  layout 'embed_user_layout'

  def show
    user = User.find_by_username(params[:id])
    unless user.present?
      user = User.find(params[:id])
      unless user.present?
        # Maybe don't break when not found?
        raise ActionController::RoutingError.new('Not Found')
      end
    end
    bikes = Bike.find(user.bikes)
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

end