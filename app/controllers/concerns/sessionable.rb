module Sessionable
  extend ActiveSupport::Concern

  SIGN_IN_SCOPE = [:controllers, :concerns, :sessionable, :sign_in_and_redirect].freeze

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

  def sign_in_and_redirect(user, signed_up: false, via_saml: false)
    if user.banned? # If user is banned, tell them about it.
      flash.now[:error] = translation(:user_is_banned, scope: SIGN_IN_SCOPE)
      redirect_back(fallback_location: new_session_url) && return
    end
    return if !via_saml && redirect_forced_saml(user.email)
    sign_in_user(user)

    if sign_in_partner.present?
      session.delete(:partner) # Only removing once signed in, PR#1435
      session.delete(:company)
      redirect_to(bikehub_url("account?reauthenticate_bike_index=true"), allow_other_host: true) && return # Only partner rn is bikehub, hardcode it
    elsif user.unconfirmed?
      render_partner_or_default_signin_layout(redirect_path: please_confirm_email_users_path) && return
    elsif !return_to_if_present
      set_sign_in_flash(user, signed_up)
      redirect_to(user_root_url) && return
    end
  end

  # Everything signing in does apart from deciding where to go next, for flows with
  # a destination of their own
  def sign_in_user(user)
    confirm_user_from_claim_token(user)
    session[:last_seen] = Time.current
    session[:render_donation_request] = user.render_donation_request if user&.render_donation_request
    set_passive_organization(user.default_organization) # Set that organization!
    user.update_last_login(forwarded_ip_address)
    if Binxtils::InputNormalizer.boolean(params.dig(:session, :remember_me)) || session.delete(:magic_link_remember_me)
      cookies.permanent.signed[ControllerHelpers::AUTH_COOKIE_KEY] = cookie_options(user)
    else
      default_session_set(user)
    end
  end

  def default_session_set(user)
    cookies.signed[ControllerHelpers::AUTH_COOKIE_KEY] = cookie_options(user)
  end

  def authenticate_user_for_my_accounts_controller
    store_return_and_authenticate_user(translation_key: :create_account, flash_type: :notice)
  end

  private

  # SSO orgs force SSO: hand an SSO-managed email off to the IdP rather than let it sign in or
  # sign up any other way. As a before_action the redirect halts the chain; called inline it
  # reports whether it redirected, since a token flow has no email until the token resolves one.
  def redirect_forced_saml(email = submitted_email)
    organization = Organization.saml_email_matching(email)
    return false if organization.blank?

    redirect_to saml_init_path(org_slug: organization.to_param)
    true
  end

  # The email an unauthenticated request is offering up, wherever its form puts it:
  # session[:email] signing in, user[:email] signing up, a bare :email elsewhere.
  def submitted_email
    params.dig(:session, :email).presence || params.dig(:user, :email).presence || params[:email]
  end

  # Passwordless users are nudged to set a password, unless their organization is what signs them in.
  # UI::Alerts::FlashMessage renders the hash - it owns the copy and builds the link
  def set_sign_in_flash(user, signed_up)
    if user.organization_passwordless_user?
      flash[:success] = translation(:organization_signed_in, scope: SIGN_IN_SCOPE)
    elsif user.passwordless_user?
      flash[:notice] = {translation_key: signed_up ? :signed_up : :signed_in,
                        url: update_password_form_with_reset_token_users_path}
    else
      # Generic, so it doesn't replace what the caller already said - resetting a password
      # signs in too, and "Logged in!" isn't the news there
      flash[:success] ||= translation(:logged_in, scope: SIGN_IN_SCOPE)
    end
  end

  def cookie_options(user)
    c = {
      httponly: true,
      value: [user.id, user.auth_token]
    }
    if Rails.env.production?
      c.merge(secure: true)
    elsif Rails.env.development?
      # Match session_store.rb domain config so auth cookie is sent on redirects
      c.merge(domain: "localhost")
    else
      c
    end
  end

  def update_user_authentication_for_new_password
    @user.generate_auth_token("auth_token") # Doesn't save user
    @user.update_auth_token("token_for_password_reset") # saves users
    @user.reload
  end
end
