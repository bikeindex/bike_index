module Sessionable
  extend ActiveSupport::Concern
  def skip_if_signed_in
    # Somehow this grabs current_user from somewhere other than ControllerHelpers (wtf??)
    # so we still have to check confirmedness. This is insane, but whatever
    store_return_to
    if unconfirmed_current_user.present? || current_user&.unconfirmed?
      redirect_to please_confirm_email_users_path and return
    end
    if current_user.present?
      return if return_to_if_present # If this returns true, we're returning already
      flash[:success] = "You're already signed in!"
      redirect_to user_home_url and return
    end
  end

  def sign_in_and_redirect(user)
    session[:last_seen] = Time.now
    if ActiveRecord::Type::Boolean.new.type_cast_from_database(params.dig(:session, :remember_me))
      cookies.permanent.signed[:auth] = cookie_options(user)
    else
      default_session_set(user)
    end

    if params[:partner].present? || session[:partner].present? # Check present? of both in case one is empty
      session[:partner] = nil # Ensure they won't be redirected in the future
      redirect_to "https://new.bikehub.com/account" and return
    elsif user.unconfirmed?
      render_partner_or_default_signin_layout(redirect_path: please_confirm_email_users_path) and return
    elsif !return_to_if_present
      flash[:success] = "Logged in!"
      redirect_to user_root_url and return
    end
  end

  def default_session_set(user)
    cookies.signed[:auth] = cookie_options(user)
  end

  protected

  def cookie_options(user)
    c = {
      httponly: true,
      value: [user.id, user.auth_token]
    }
    # In development, secure: true breaks the cookie storage. Only add if production
    Rails.env.production? ? c.merge(secure: true) : c
  end
end
