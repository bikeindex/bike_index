class SessionsController < ApplicationController
  include Sessionable
  layout 'application_revised'
  before_filter :store_return_to, only: [:new]
  before_filter :skip_if_signed_in, only: [:new]

  def new
  end

  def create
    @user = User.fuzzy_email_find(permitted_parameters[:email])
    if @user.present? && @user.confirmed?
      if @user.authenticate(permitted_parameters[:password])
        sign_in_and_redirect
      else
        # User couldn't authenticate, so password is invalid
        flash.now[:error] = 'Invalid email/password'
        # If user is banned, tell them about it.
        if @user.banned?
          flash.now[:error] = "We're sorry, but it appears that your account has been locked. If you are unsure as to the reasons for this, please contact us"
        end
        render :new
      end
    elsif (@user && @user.confirmed?) || User.fuzzy_unconfirmed_primary_email_find(permitted_parameters[:email]).present?
      # Email address is not confirmed
      flash.now[:error] = 'You must confirm your email address to continue'
      render :new
    else
      # Email address is not in the DB
      flash.now[:error] = 'Invalid email/password'
      render :new
    end
  end

  def destroy
    remove_session
    if params[:redirect_location].present?
      if params[:redirect_location].match('new_user')
        redirect_to new_user_path, notice: 'Logged out!' and return
      end
    end
    redirect_to goodbye_url(subdomain: false), notice: 'Logged out!'
  end

  private

  def permitted_parameters
    params.require(:session).permit(:password, :email, :remember_me)
  end
end
