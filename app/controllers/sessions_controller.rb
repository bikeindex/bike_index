=begin
*****************************************************************
* File: app/controllers/sessions_controller.rb 
* Name: Class SessionsController 
* Set some methods to deal with session
*****************************************************************
=end

class SessionsController < ApplicationController
  include Sessionable
  before_filter :set_return_to, only: [:new]

  def new
    if current_user.present?
      redirect_to user_home_url, notice: "You're already signed in, silly! You can log out by clicking on 'Your Account' in the upper right corner"
    else
      #nothing to do
    end  
    if revised_layout_enabled?
      render 'new_revised', layout: 'application_revised'
    else
      #nothing to do
    end
  end

  def create
    @user = User.fuzzy_email_find(params[:session][:email])
    assert_object_is_not_null(@user)
    if @user.present?
      if @user.confirmed?
        if @user.authenticate(params[:session][:password])
          sign_in_and_redirect
        else
          # User couldn't authenticate, so password is invalid
          flash.now.alert = 'Invalid email/password'
          # If user is banned, tell them about it.
          if @user.banned?
            flash.now.alert = "We're sorry, but it appears that your account has been locked. If you are unsure as to the reasons for this, please contact us"
          else
            render :new
          end
        end
      else
        # Email address is not confirmed
        flash.now.alert = 'You must confirm your email address to continue'
        render :new
      end
    else
      # Email address is not in the DB
      flash.now.alert = 'Invalid email/password'
      render 'new'
    end  
  end

  def destroy
    remove_session
    if params[:redirect_location].present?
      if params[:redirect_location].match('new_user')
        redirect_to new_user_path, notice: 'Logged out!' and return
      else
        #nothing to do
      end
    else
      redirect_to goodbye_url(subdomain: false), notice: 'Logged out!'   
    end
  end
  
end
