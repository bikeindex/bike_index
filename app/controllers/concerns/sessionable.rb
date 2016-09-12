module Sessionable
  extend ActiveSupport::Concern
  def skip_if_signed_in
    return nil unless current_user.present?
    unless return_to_if_present
      flash[:success] = "You're already signed in!"
      redirect_to user_home_url and return
    end
  end

  def sign_in_and_redirect
    session[:last_seen] = Time.now
    if params[:session].present? && params[:session][:remember_me].present? && params[:session][:remember_me].to_s == '1'
      cookies.permanent.signed[:auth] = cookie_options
    else
      default_session_set
    end
    unless return_to_if_present
      flash[:success] = 'Logged in!'
      redirect_to user_root_url and return
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
    Rails.env.production? ? c.merge(secure: true) : c
  end
end
