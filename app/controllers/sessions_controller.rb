class SessionsController < ApplicationController
  include Sessionable
  layout "application_revised"
  before_action :skip_if_signed_in, only: [:new]

  def new
    render_partner_or_default_signin_layout
  end

  def create
    @user = User.fuzzy_confirmed_or_unconfirmed_email_find(permitted_parameters[:email])
    pp session.as_json

    if @user.present?
      if @user.authenticate(permitted_parameters[:password])
        sign_in_and_redirect(@user)
      else
        # User couldn't authenticate, so password is invalid
        flash.now[:error] = "Invalid email/password"
        # If user is banned, tell them about it.
        if @user.banned?
          flash.now[:error] = "We're sorry, but it appears that your account has been locked. If you are unsure as to the reasons for this, please contact us"
        end
        render_partner_or_default_signin_layout(render_action: :new)
      end
    else
      # Email address is not in the DB
      flash.now[:error] = "Invalid email/password"
      render_partner_or_default_signin_layout(render_action: :new)
    end
  end

  def destroy
    remove_session
    if params[:redirect_location].present?
      if params[:redirect_location].match("new_user")
        redirect_to new_user_path, notice: "Logged out!" and return
      end
    end
    redirect_to goodbye_url(subdomain: false), notice: "Logged out!"
  end

  private

  def permitted_parameters
    params.require(:session).permit(:password, :email, :remember_me)
  end
end
