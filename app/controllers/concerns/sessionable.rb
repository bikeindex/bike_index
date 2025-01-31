module Sessionable
  extend ActiveSupport::Concern

  def skip_if_signed_in
    store_return_to
    # Make absolutely sure we don't have an unconfirmed user
    if unconfirmed_current_user.present? || current_user&.unconfirmed?
      redirect_to(please_confirm_email_users_path) && return
    end
    if current_user.present?
      return if return_to_if_present # If this returns true, we're returning already
      flash[:success] = translation(:already_signed_in, scope: [:controllers, :concerns, :sessionable, __method__])
      redirect_to(user_root_url) && return
    end
  end

  def sign_in_and_redirect(user)
    if user.banned? # If user is banned, tell them about it.
      flash.now[:error] = translation(:user_is_banned, scope: [:controllers, :concerns, :sessionable, __method__])
      redirect_back(fallback_location: new_session_url) && return
    end
    session[:last_seen] = Time.current
    session[:render_donation_request] = user.render_donation_request if user&.render_donation_request
    set_passive_organization(user.default_organization) # Set that organization!
    user.update_last_login(forwarded_ip_address)
    if InputNormalizer.boolean(params.dig(:session, :remember_me))
      cookies.permanent.signed[:auth] = cookie_options(user)
    else
      default_session_set(user)
    end

    if sign_in_partner.present?
      session.delete(:partner) # Only removing once signed in, PR#1435
      session.delete(:company)
      redirect_to(bikehub_url("account?reauthenticate_bike_index=true"), allow_other_host: true) && return # Only partner rn is bikehub, hardcode it
    elsif user.unconfirmed?
      render_partner_or_default_signin_layout(redirect_path: please_confirm_email_users_path) && return
    elsif !return_to_if_present
      flash[:success] = translation(:logged_in, scope: [:controllers, :concerns, :sessionable, __method__])
      redirect_to(user_root_url) && return
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

  def update_user_authentication_for_new_password
    @user.generate_auth_token("auth_token") # Doesn't save user
    @user.update_auth_token("token_for_password_reset") # saves users
    @user.reload
  end
end
