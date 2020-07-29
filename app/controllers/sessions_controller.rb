class SessionsController < ApplicationController
  include Sessionable
  before_action :skip_if_signed_in, only: [:new, :magic_link]

  def new
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
      user.update_attributes(magic_link_token: nil)
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
        membership = Membership.create_passwordless(invited_email: params[:email],
                                                    created_by_magic_link: true,
                                                    organization_id: matching_organization.id)
        user = membership.user
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
        # User couldn't authenticate, so password is invalid
        flash.now[:error] = translation(:invalid_email_or_password)
        # If user is banned, tell them about it.
        if @user.banned?
          flash.now[:error] = translation(:user_is_banned)
        end
        render_partner_or_default_signin_layout(render_action: :new)
      end
    else
      # Email address is not in the DB
      flash.now[:error] = translation(:invalid_email_or_password)
      render_partner_or_default_signin_layout(render_action: :new)
    end
  end

  def destroy
    remove_session
    if params[:partner] == "bikehub"
      redirect_to("https://parkit.bikehub.com") && return
    elsif params[:redirect_location].present?
      if params[:redirect_location].match?("new_user")
        redirect_to(new_user_path, notice: "Logged out!") && return
      end
    end
    redirect_to goodbye_url(subdomain: false), notice: "Logged out!"
  end

  private

  def permitted_parameters
    params.require(:session).permit(:password, :email, :remember_me)
  end
end
