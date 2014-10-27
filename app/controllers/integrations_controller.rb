class IntegrationsController < ApplicationController
  include Sessionable
 
  def create
    @integration = Integration.new    
    @integration.access_token = request.env['omniauth.auth']['credentials']['token']
    @integration.provider_name = request.env['omniauth.auth']['provider']
    @integration.information = request.env['omniauth.auth']
    if @integration.save
      @user = @integration.user
      sign_in_and_redirect
      # cookies.permanent[:auth_token] = @integration.user.auth_token
      # session[:last_seen] = Time.now
      # redirect_to user_home_url, notice: "Logged in!"
    else
      flash[:notice] = "There was a problem authenticating you with facebook. Please try To sign in a different way."
      redirect_to new_session_url
    end
  end
end
