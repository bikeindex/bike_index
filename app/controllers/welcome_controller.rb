class WelcomeController < ApplicationController
  # caches_page :index
  before_filter :authenticate_user!, only: :user_home
  
  def index
    render action: 'index', layout: 'no_container'
  end

  def update_browser
    render action: 'update_browser', layout: false
  end

  def goodbye
  end

  def user_home
    if current_user.present?
      bikes = Bike.where('id in (?)', current_user.bikes).includes(:cycle_type, :manufacturer, :primary_frame_color, :secondary_frame_color, :tertiary_frame_color)
      @bikes = BikeDecorator.decorate_collection(bikes)
      @locks = LockDecorator.decorate_collection(current_user.locks)

      if current_user.can_invite && current_user.has_membership?
        @bike_token_invitation = BikeTokenInvitation.new
      end
      render action: 'user_home', layout: 'no_container'
    else
      flash[:notice] = "Woops, you have to log in to be able to do that"  
      redirect_to new_session_url
    end
  end

  def choose_registration
    @user = User.new unless current_user.present?
  end
end
