class DiscourseAuthenticationController < ApplicationController
  before_filter :authenticate_and_set_redirect

  def index
    sso = SingleSignOn.parse(session[:discourse_redirect], discourse_secret)
    sso.email = current_user.email
    sso.name = current_user.name
    sso.external_id = current_user.id
    session[:discourse_redirect] = nil
    redirect_to sso.to_url(discourse_redirect_url) and return
  end

  private

  def discourse_secret
    ENV['DISCOURSE_SECRET']
  end

  def discourse_redirect_url
    "#{ENV['DISCOURSE_URL']}/session/sso_login"
  end

  def authenticate_and_set_redirect
    session[:discourse_redirect] ||= request.query_string
    unless current_user.present?
      redirect_to new_session_path and return
    end
  end
end
