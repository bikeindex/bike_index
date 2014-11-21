class SessionsController < ApplicationController
  include Sessionable
  def new
    session[:return_to] = params[:return_to] if params[:return_to].present?
    if current_user.present?
      redirect_to user_home_url, notice: "You're already signed in, silly! You can log out by clicking on 'Your Account' in the upper right corner"
    end
  end

  def create
    # @photos = PublicImage.limit(18).order("created_at desc")
    @user = User.fuzzy_email_find(params[:session][:email])

    if @user.present?
      if @user.confirmed?
        if @user.authenticate(params[:session][:password])
          sign_in_and_redirect
        else
          # User couldn't authenticate, so password is invalid
          flash.now.alert = "Invalid email/password"
          # If user is banned, tell them about it.
          if @user.banned?
            flash.now.alert = "We're sorry, but it appears that your account has been locked. If you are unsure as to the reasons for this, please contact us"
          end
          render "new"
        end
      else
        # Email address is not confirmed
        flash.now.alert = "You must confirm your email address to continue"
        render "new"
      end
    else
      # Email address is not in the DB
      flash.now.alert = "Invalid email/password"
      render "new"
    end
  end

  def destroy
    cookies.delete(:auth)
    if params[:redirect_location].present?
      if params[:redirect_location].match('new_user')
        redirect_to new_user_path, notice: "Logged out!" and return
      end
    end
    redirect_to goodbye_url(subdomain: false), notice: "Logged out!"
  end


end
