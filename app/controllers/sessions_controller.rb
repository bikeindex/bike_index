class SessionsController < ApplicationController
  include Sessionable

  before_action :force_html_response
  before_action :skip_if_signed_in, only: [:new, :magic_link]

  def new
    render_partner_or_default_signin_layout
  end

  # Dropbox-style identifier-first: the first screen collects only an email; this
  # decides what the second screen asks for (or where to send them) from that email.
  def identify
    @email = permitted_parameters[:email]
    return render_partner_or_default_signin_layout(render_action: :new) if @email.blank?

    @login_method = login_method_for(@email)
    # "sso" will join this branch once the SAML SP lands (redirect to the IdP).
    if @login_method == "password" && User.fuzzy_confirmed_or_unconfirmed_email_find(@email).blank?
      # No account — start sign-up with the entered email pre-filled.
      redirect_to new_user_path(email: @email, partner: sign_in_partner)
    else
      render_partner_or_default_signin_layout(render_action: :identify)
    end
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
      user.send_magic_link_email
      flash[:success] = translation(:link_sent)
      redirect_to root_path
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
        # Wrong password — stay on the credential step with the email preserved
        flash.now[:error] = translation(:invalid_email_or_password)
        @email = permitted_parameters[:email]
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
  # eventual sign-in redirect already would. "sso" will slot in here once the
  # SAML SP lands; today only passwordless-domain orgs diverge from password.
  def login_method_for(email)
    return "password" if email.blank?
    Organization.passwordless_email_matching(email).present? ? "magic_link" : "password"
  end

  def permitted_parameters
    params.require(:session).permit(:password, :email, :remember_me)
  end
end
