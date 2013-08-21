class WelcomeController < ApplicationController
  caches_page :index
  before_filter :authenticate_user!, only: :user_home
  
  def index
    render action: 'index', layout: 'no_container'
  end

  def goodbye
    @title = "goodbye"
  end

  def bust_z_cache
    Rails.cache.clear
    redirect_to root_url
  end

  def user_home
    @title = "Home"
    if current_user.present?
      bikes = Bike.find(current_user.bikes)
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
    unless current_user.present?
      flash[:notice] = "Please create an account first!"
      redirect_to new_user_path and return
    end
    @title = "Add a bike"
  end

end
