class IntegrationsController < ApplicationController
  include Sessionable
  before_filter :store_return_to
 
  def create
    @integration = Integration.new
    @integration.access_token = request.env['omniauth.auth']['credentials']['token']
    @integration.provider_name = request.env['omniauth.auth']['provider']
    @integration.information = request.env['omniauth.auth']
    @integration.associate_with_user
    if @integration.save && @integration.user.present?
      @user = @integration.user
      sign_in_and_redirect
    else
      integrations_controller_creation_error
    end
  end

  def integrations_controller_creation_error
    provider_name = request.env['omniauth.auth'] && request.env['omniauth.auth']['provider']
    provider_name ||= params[:strategy]
    msg = "There was a problem authenticating you with #{provider_name}"
    msg += ". Please sign in a different way or email us at contact@bikeindex.org"
    flash[:error] = msg
    redirect_to new_session_path and return
  end
end
