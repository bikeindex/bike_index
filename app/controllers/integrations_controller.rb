class IntegrationsController < ApplicationController
  include Sessionable
  before_filter :skip_if_signed_in

  def create
    @integration = Integration.new(information: request.env['omniauth.auth'],
                                   access_token: request.env['omniauth.auth']['credentials']['token'],
                                   provider_name: request.env['omniauth.auth']['provider'])
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
    msg = "There was a problem authenticating you with #{provider_name}. Please sign in a different way or email us at contact@bikeindex.org"
    flash[:error] = msg
    redirect_to new_session_path and return
  end
end
