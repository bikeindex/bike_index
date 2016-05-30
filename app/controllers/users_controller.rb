=begin
*****************************************************************
* File: app/controllers/users_controller.rb 
* Name: Class UsersController 
* Set some methods to deal with the profile of users
*****************************************************************
=end

class UsersController < ApplicationController
  include Sessionable
  before_filter :authenticate_user, only: [:edit]
  before_filter :set_return_to, only: [:new]

=begin
  Name: new
  Explication: method to create a new user 
  Params: create a new user
  Return: redirect to home or render new revise or nothing
=end  
  def new
    @user = User.new
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@user.kind_of?(User))
    if current_user.present?
      flash[:notice] = "You're already signed in, silly! You can log out by clicking on 'Your Account' in the upper right corner"
      redirect_to user_home_url and return
    else
      #nothing to do
    end
    if revised_layout_enabled?
      render 'new_revised', layout: 'application_revised'
    else
      #nothing to do  
    end
  end

=begin
  Name: create
  Explication: create a new instance of user 
  Params: receive user created in action new
  Return: sign in or render new template to create user
=end
  def create
    @user = User.new(params[:user])
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@user.kind_of?(User))
    if @user.save
      CreateUserJobs.new(user: @user).do_jobs
      sign_in_and_redirect if @user.confirmed
    else
      render action: :new
    end
  end

=begin
  Name: confirm
  Explication: method to confirm if user search is the same 
  Params: specific user by id and code which confirm the user
  Return: redirect to new session or sign in or render confirm error bad token or render confirm error 404
=end
  def confirm
    begin
      @user = User.find(params[:id])
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_object_is_not_null(@user)
      if @user.confirmed?
        redirect_to new_session_url, notice: "Your user account is already confirmed. Please log in"
      else
        if @user.confirm(params[:code])
          sign_in_and_redirect
        else
          render :confirm_error_bad_token
        end
      end
    rescue ActiveRecord::RecordNotFound
      render :confirm_error_404
    end
  end

=begin
  Name: request_password_reset 
  Explication: none 
  Params: none
  Return: nothing
=end
  def request_password_reset
  end

=begin
  Name: update_password
  Explication: method to update password of the current user  
  Params: none
  Return: current user
=end
  def update_password
    @user = current_user
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@user.kind_of?(User))
    return @user
  end

=begin
  Name: password_reset
  Explication: method used to password reset user 
  Params: simbol token and specific user find by email
  Return: sign in or render action request password reset or user reset datas
=end
  def password_reset
    if params[:token].present?
      @user = User.find_by_password_reset_token(params[:token])
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_object_is_not_null(@user)
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_message(@user.kind_of?(User))
      if @user.present?
        session[:return_to] = 'password_reset'
        sign_in_and_redirect
      else
        flash[:error] = "We're sorry, but that link is no longer valid."
        render action: :request_password_reset
      end
    if params[:email].present?
      @user = User.fuzzy_email_find(params[:email])
      if @user.present?
        @user.send_password_reset_email
      else
        flash[:error] = "Sorry, that email address isn't in our system."
        render action: :request_password_reset
      end
    else
      redirect_to '/users/request_password_reset'
    end  
  end

=begin
  Name: show
  Explication: method used to find user and to show information 
  Params: user's id
  Return: not found or redirect to user home
=end
  def show
    user = User.find_by_username(params[:id])
    unless user 
      raise ActionController::RoutingError.new('Not Found')
    end
    @owner = user
    @user = user.decorate
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    if user == current_user
      # Render the site
    else
      unless @user.show_bikes
        redirect_to user_home_url, notice: "Sorry, that user isn't sharing their bikes" and return
      end
    end
    bikes = user.bikes(true)
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

=begin
  Name: edit
  Explication: method used to edit the profile current user  
  Params: none
  Return: @user 
=end
  def edit
    @user = current_user
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@user.kind_of?(current_user))
    return @user
  end

=begin
  Name: update
  Explication:  method which basically update the user datas
  Params: receive the user datas, as: password, email and current user; 
  Return: errors with some this message: "Doesn't match user's password reset token", "Password reset token expired, try resetting password again", "Current password doesn't match, it's required for updating your password" or nothing to to or some others possibility: redirect_to user_home_url or redirect_to my_account_url or redirect_to accept_vendor_terms_url.
=end
  def update
    @user = current_user
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@user)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@user.kind_of?(current_user))
    if params[:user][:password_reset_token].present?
      if @user.password_reset_token != params[:user][:password_reset_token]
        @user.errors.add(:base, "Doesn't match user's password reset token")
      else
        #nothing to do
      end  
      if @user.reset_token_time < (Time.now - 1.hours)
        @user.errors.add(:base, "Password reset token expired, try resetting password again")
      else
        #nothing to do
      end
      if params[:user][:password].present?
        unless @user.authenticate(params[:user][:current_password])
        @user.errors.add(:base, "Current password doesn't match, it's required for updating your password")
        end
      else
        #nothing to do
      end    
    else 
      #nothing to do 
    end
    if !@user.errors.any? && @user.update_attributes(params[:user].except(:email, :password_reset_token))
      AfterUserChangeWorker.perform_asynchronous(@user.id)
      if params[:user][:terms_of_service].present?
        if params[:user][:terms_of_service] == '1'
          @user.terms_of_service = true
          @user.save
          redirect_to user_home_url, notice: "Thanks! Now you can use the Bike Index" and return
        else
          redirect_to accept_vendor_terms_url, notice: "You have to accept the Terms of Service if you would like to use Bike Index" and return
        end
      else
        #nothing to do
      end  
      if params[:user][:vendor_terms_of_service].present? 
        if params[:user][:vendor_terms_of_service] == '1'
          @user.accept_vendor_terms_of_service
          if @user.memberships.any?
            flash[:notice] = "Thanks! Now you can use Bike Index as #{@user.memberships.first.organization.name}"
          else
            flash[:notice] = "Thanks for accepting the terms of service!"
          end
          redirect_to user_home_url and return
          # TODO: Redirect to the correct page, somehow this breaks things right now though.
          # redirect_to organization_home and return
        else
          redirect_to accept_vendor_terms_url, notice: "You have to accept the Terms of Service if you would like to use Bike Index as through the organization" and return
        end
      else
        #nothing to do  
      end
      if params[:user][:password].present?
        @user.generate_auth_token
        @user.set_password_reset_token
        @user.reload
        default_session_set
      else
        redirect_to my_account_url, notice: 'Your information was successfully updated.' and return
      end
    else
      render action: :edit
    end    
  end

=begin
  Name: accept_terms
  Explication: verify if user is present to accept terms of contract  
  Params: none
  Return: @user or redirect to terms page 
=end
  def accept_terms
    if current_user.present?
      @user = current_user
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_object_is_not_null(@user)
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_message(@user.kind_of?(current_user))
      return @user
    else
      redirect_to terms_url
    end
  end

=begin
  Name: accept_vendor_terms
  Explication: verify if user is present to accept vendor terms of contract  
  Params: none
  Return: @user or redirect to vendor terms page 
=end
  def accept_vendor_terms
    if current_user.present?
      @user = current_user
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_object_is_not_null(@user)
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_message(@user.kind_of?(current_user))
      return @user
    else
      redirect_to vendor_terms_url
    end
  end

end
