class IntegrationsController < ApplicationController
  include Sessionable
  before_action :skip_if_signed_in

  def create
    @integration = Integration.new(information: request.env["omniauth.auth"],
                                   access_token: request.env["omniauth.auth"]["credentials"]["token"],
                                   provider_name: request.env["omniauth.auth"]["provider"])
    @integration.save
    if @integration.valid? && @integration.user.present?
      @user = @integration.user
      @user.reload
      sign_in_and_redirect(@user)
    else
      integrations_controller_creation_error
    end
  end

  def integrations_controller_creation_error
    provider_name = request.env["omniauth.auth"] && request.env["omniauth.auth"]["provider"]
    provider_name ||= params[:strategy]

    flash[:error] = translation(:problem_authenticating_with_provider,
      provider_name: provider_name)
    redirect_to(new_session_path) && return
  end
end
