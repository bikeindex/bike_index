=begin
*****************************************************************
* File: app/controllers/welcome_controller.rb 
* Name: Class WelcomeController 
* Set some methods to deal with the welcome of the users
*****************************************************************
=end

class WelcomeController < ApplicationController

=begin
  Name: index
  Explication: show the welcome page to bike index 
  Params: none
  Return: layout of action index
=end
  def index
    render action: 'index', layout: (revised_layout_enabled? ? 'application_revised' : 'application_updated')
  end

=begin
  Name: update_browser 
  Explication: method to update browser in the application
  Params: none
  Return: update browser
=end
  def update_browser
    render action: 'update_browser', layout: false
  end

=begin
  Name: goodbye
  Explication: method to logout the user 
  Params: none
  Return: logout or null
=end
  def goodbye
    redirect_to logout_url if current_user.present?
  end

=begin
  Name: user_home
  Explication: method to verify the current user and to decorator bike or lock
  Params: bikes store in database and current user
  Return: action user_home or new_user_url
=end
  def user_home
    if current_user.present?
      bikes = current_user.bikes
      @bikes = BikeDecorator.decorate_collection(bikes)
      @locks = LockDecorator.decorate_collection(current_user.locks)
      render action: 'user_home', layout: 'no_container'
    else
      redirect_to new_user_url
    end
  end

=begin
  Name: choose_registration 
  Explication: method to choose the user to registration or create a new
  Params: receive current user or create a new
  Return: @user
=end
  def choose_registration
    @user = User.new unless current_user.present?
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    return @user
  end

end
