=begin
*****************************************************************
* File: app/controllers/discouse_authentication_controller.rb 
* Name: Class DiscourseAuthenticationController 
* Some methods to do authentication
*****************************************************************
=end

class DiscourseAuthenticationController < ApplicationController

  before_filter :authenticate_and_set_redirect

=begin
  Name: index
  Explication: define sigle sign on methods
  Paramts: user params, email, name and id
  Return: redirect user to discourser url 
  remember that sso it's the abbreviation of Single Sign On
=end
  
  def index
    sso = SingleSignOn.parse(session[:discourse_redirect], discourse_secret)
    sso.email = current_user.email
    sso.name = current_user.name
    sso.external_id = current_user.id
    session[:discourse_redirect] = nil
    redirect_to sso.to_url(discourse_redirect_url) and return
  end

  private

=begin
  Name: discourse_secret
  Explication: 
=end
  
  def discourse_secret
    ENV['DISCOURSE_SECRET']
  end

=begin
  Name: discourse_redirect_url
  Explication:  
=end
  
  def discourse_redirect_url
    "#{ENV['DISCOURSE_URL']}/session/sso_login"
  end

=begin
  Name: show
  Explication: check if user is logged in 
  Paramts: current user present
  Return: redirect user to login page  
=end
  
  def authenticate_and_set_redirect
    session[:discourse_redirect] ||= request.query_string
    unless current_user.present?
      redirect_to new_session_path and return
    end
  end
end
