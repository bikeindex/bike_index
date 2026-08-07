class SessionsController < ApplicationController
  include Sessionable

  before_action :force_html_response
  before_action :skip_if_signed_in, only: [:new, :magic_link]
  # SSO orgs force SSO: every entry point that submits an email redirects an SSO-managed one
  # to the IdP before the action runs, so no password or new magic link gets issued for it.
  # sign_in_with_magic_link is absent because it submits a token rather than an email — a link
  # issued before the org moved to SSO still signs in until that token expires.
  before_action :redirect_forced_saml, only: %i[identify create create_magic_link]

  def new
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
    @incorrect_token = params[:incorrect_token].presence
  end

  def sign_in_with_magic_link
    user = User.find_by_magic_link_token(params[:token])
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
    if user.blank?
      matching_organization = Organization.passwordless_email_matching(params[:email])
      if matching_organization.present?
        organization_role = OrganizationRole.create_passwordless(invited_email: params[:email],
          created_by_magic_link: true,
          organization_id: matching_organization.id)
        user = organization_role.user
      end
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

  # See the before_action: hand an SSO-managed email off to the IdP. Redirecting here
  # halts the filter chain, so the action never runs for a forced-SSO email.
  def redirect_forced_saml
    organization = Organization.saml_email_matching(submitted_email)
    redirect_to saml_init_path(org_slug: organization.to_param) if organization.present?
  end

  def send_magic_link_and_redirect(user)
    # Stash the remember-me choice so the emailed-link GET (which carries no form
    # params) can still honor it in sign_in_and_redirect.
    session[:magic_link_remember_me] = Binxtils::InputNormalizer.boolean(submitted_remember_me)
    user.send_magic_link_email
    redirect_to magic_link_sent_session_path(partner: sign_in_partner)
  end

  # The three guarded actions carry the email in different params: identify/create post
  # session[:email]; create_magic_link posts a top-level :email.
  def submitted_email
    params.dig(:session, :email).presence || params[:email]
  end

  def submitted_remember_me
    params.dig(:session, :remember_me).presence || params[:remember_me]
  end

  def permitted_parameters
    params.require(:session).permit(:password, :email, :remember_me)
  end
end
