class SessionsController < ApplicationController
  include Sessionable

  before_action :force_html_response
  before_action :skip_if_signed_in, only: [:new, :magic_link]
  # SSO orgs force SSO: every entry point that submits an email redirects an SSO-managed one
  # to the IdP before the action runs, so no password or new magic link gets issued for it.
  # sign_in_with_magic_link submits a token rather than an email, so it is caught downstream in
  # sign_in_and_redirect instead, once the token has resolved a user.
  before_action :redirect_forced_saml, only: %i[identify create create_magic_link]

  def new
    @email = params[:email]
    render_partner_or_default_signin_layout
  end

  # Dropbox-style identifier-first: the first screen collects only an email; this
  # decides what the second screen asks for (or where to send them) from that email.
  def identify
    # dig rather than require(:session) so a bare GET (reload/bookmark/back) doesn't
    # raise ParameterMissing — it falls through to re-rendering the email step.
    @email = params.dig(:session, :email)
    @remember_me = params.dig(:session, :remember_me)
    return render_partner_or_default_signin_layout(render_action: :new) if @email.blank?

    user = User.fuzzy_confirmed_or_unconfirmed_email_find(@email)
    # Passwordless users have no password to enter, so skip the credential step
    return send_magic_link_and_redirect(user) if user&.passwordless_user?

    @login_method = login_method_for(@email)
    if @login_method == "password" && user.blank?
      # No account — start sign-up with the entered email pre-filled.
      redirect_to new_user_path(email: @email, partner: sign_in_partner)
    else
      render_partner_or_default_signin_layout(render_action: :identify)
    end
  end

  def magic_link_sent
    render_partner_or_default_signin_layout
  end

  def magic_link
    @token = params[:token]
    @return_to = params[:return_to]
    @failure = magic_link_failure(params[:incorrect_token]) if params[:incorrect_token].present?
  end

  def sign_in_with_magic_link
    user = User.find_for_auth_token("magic_link_token", params[:token])
    if user.present? && !user.auth_token_expired?("magic_link_token")
      user.confirm(user.confirmation_token) unless user.confirmed?
      @user = user
      user.update(magic_link_token: nil)
      sign_in_and_redirect(@user)
    else
      redirect_to magic_link_session_path(incorrect_token: params[:token])
    end
  end

  def create_magic_link
    user = User.fuzzy_confirmed_or_unconfirmed_email_find(params[:email])
    # Claiming a domain for passwordless sign-in is enough to mint the account, nothing more.
    # A role only follows if the org also has user_role_for_user_email_domain, which
    # CallbackJobs::AfterUserCreateJob grants once the new user is confirmed.
    if user.blank? && Organization.passwordless_email_matching(params[:email]).present?
      user = UserServices::PasswordlessCreator.find_or_create(params[:email]).first
    end
    if user.present?
      send_magic_link_and_redirect(user)
    else
      flash[:error] = translation(:user_not_found)
      redirect_to new_user_path
    end
  end

  def create
    @user = User.fuzzy_confirmed_or_unconfirmed_email_find(permitted_parameters[:email])
    if @user.present?
      if @user.authenticate(permitted_parameters[:password])
        sign_in_and_redirect(@user)
      else
        # Wrong password — stay on the credential step, preserving the email and
        # the keep-me-logged-in choice carried from the email step
        flash.now[:error] = translation(:invalid_email_or_password)
        @email = permitted_parameters[:email]
        @remember_me = permitted_parameters[:remember_me]
        @login_method = "password"
        render_partner_or_default_signin_layout(render_action: :identify)
      end
    else
      # Email address is not in the DB — back to the email step
      flash.now[:error] = translation(:invalid_email_or_password)
      render_partner_or_default_signin_layout(render_action: :new)
    end
  end

  # Hand back the form they submitted rather than dumping them at user_root_url
  def handle_unverified_request
    flash.now[:error] = invalid_authenticity_token_message
    case action_name
    when "sign_in_with_magic_link"
      @token = params[:token]
      @return_to = params[:return_to]
      render_partner_or_default_signin_layout(render_action: :magic_link)
    when "identify", "create", "create_magic_link"
      @email = submitted_email
      render_partner_or_default_signin_layout(render_action: :new)
    else
      super
    end
  end

  def destroy
    remove_session
    if params[:partner] == "bikehub"
      redirect_to(bikehub_url, allow_other_host: true) && return
    elsif params[:redirect_location].present?
      if params[:redirect_location].match?("new_user")
        redirect_to(new_user_path, notice: "Logged out!") && return
      end
    end

    redirect_to goodbye_url, notice: "Logged out!"
  end

  private

  # Which credential an email's organization requires. Determined by org domain
  # preference only (never account existence), so this leaks no more than the
  # eventual sign-in redirect already would. SSO orgs are handled by the
  # redirect_forced_saml before_action; here only magic-link vs password remains.
  def login_method_for(email)
    Organization.passwordless_email_matching(email).present? ? "magic_link" : "password"
  end

  # A dead token matches no user whatever killed it, so its timestamp is all that's left to read
  def magic_link_failure(token)
    return :unrecognized unless SecurityTokenizer.recognized_token?(token)

    expired = SecurityTokenizer.token_time(token) < Time.current - User::AUTH_TOKEN_EXPIRY
    expired ? :expired : :already_used
  end

  def send_magic_link_and_redirect(user)
    # Stash the remember-me choice so the emailed-link GET (which carries no form
    # params) can still honor it in sign_in_and_redirect.
    session[:magic_link_remember_me] = Binxtils::InputNormalizer.boolean(submitted_remember_me)
    user.send_magic_link_email(return_to: session[:return_to])
    redirect_to magic_link_sent_session_path(partner: sign_in_partner)
  end

  def submitted_remember_me
    params.dig(:session, :remember_me).presence || params[:remember_me]
  end

  def permitted_parameters
    params.require(:session).permit(:password, :email, :remember_me)
  end
end
