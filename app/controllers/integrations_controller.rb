=begin
*****************************************************************
* File: app/controllers/integrations_controller.rb 
* Name: Class IntegrationsController 
* Class that contain methods to integration between session
* and authentication
*****************************************************************
=end

class IntegrationsController < ApplicationController
  include Sessionable
 
=begin
  Explication: create integration for user
  Params: user params and integration
  Return: sign_in_and_redirect
=end 
  def create
    @integration = Integration.new
    @integration.access_token = request.env['omniauth.auth']['credentials']['token']
    @integration.provider_name = request.env['omniauth.auth']['provider']
    @integration.information = request.env['omniauth.auth']
    if @integration.save
      @user = @integration.user
      sign_in_and_redirect
    else
      integrations_controller_creation_error
    end
  end

=begin
  Explication: control of creation integration for user
  Params: integration
  Return: redirect_to new_session_url and return
=end 
  def integrations_controller_creation_error
    provider_name = request.env['omniauth.auth']['provider']
    flash[:notice] = "There was a problem authenticating you with #{provider_name}. Please try To sign in a different way."
    redirect_to new_session_url and return
  end
end
