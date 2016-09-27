class UserEmailsController < ApplicationController
  before_filter :ensure_user_email_ownership

  def resend_confirmation
    flash[:success] = 'Email confirmation re-sent'
    @user_email.send_confirmation_email
    redirect_to my_account_path
  end

  def confirm
    if @user_email.confirm(params[:confirmation_token])
      flash[:success] = "#{@user_email.email} has been confirmed and added to your account. It may take up to an hour for the attributes from your account to fully merge in, please be patient."
    elsif @user_email.confirmed
      flash[:info] = "#{@user_email.email} is already confirmed. It may take up to an hour for the attributes from your account to fully merge in, please be patient."
    else
      flash[:error] = "Incorrect token for #{@user_email.email}. Try resending the confirmation email"
    end
    redirect_to my_account_path
  end

  def make_primary
    if @user_email.confirmed
      @user_email.make_primary
      flash[:success] = "#{@user_email.email} has been made your primary email."
    else
      flash[:info] = "You must confirm #{@user_email.email} before making it your primary email"
    end
    redirect_to my_account_path
  end

  def destroy
    if @user_email.confirmed
      flash[:info] = "#{@user_email.email} is confirmed and can't be removed. Email contact@bikeindex.org for help."
    elsif @user_email.user.user_emails.count < 2
      flash[:info] = "#{@user_email.email} is your only confirmed email and can't be removed. Email contact@bikeindex.org for help."
    else
      flash[:success] = "#{@user_email.email} removed."
      @user_email.destroy
    end
    redirect_to my_account_path
  end

  private

  def ensure_user_email_ownership
    unless current_user && current_user.user_emails.pluck(:id).include?(params[:id].to_i)
      flash[:error] = "You must be signed in with primary email! Email contact@bikeindex.org if this doesn't make sense."
      redirect_to user_root_url and return
    end
    @user_email = current_user.user_emails.find(params[:id])
  end
end
