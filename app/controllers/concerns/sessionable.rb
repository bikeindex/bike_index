module Sessionable
  extend ActiveSupport::Concern

  def sign_in_and_redirect
    session[:last_seen] = Time.now
    if params[:session].present? && params[:session][:remember_me].present? && params[:session][:remember_me].to_s == '1'
      cookies.permanent.signed[:auth] = cookie_options
    else
      default_session_set
    end

    unless return_to_if_present
      redirect_to user_root_url, notice: "Logged in!" and return
    end
  end

  def default_session_set
    cookies.signed[:auth] = cookie_options
  end

  protected

  def cookie_options
    c = {
      httponly: true,
      value: [@user.id, @user.auth_token]
    }
    # In development, secure: true breaks the cookie storage. Only add if production
    Rails.env.production? ? c.merge({secure: true}) : c
  end
end
