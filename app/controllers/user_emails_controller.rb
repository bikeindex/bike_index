class UserEmailsController < ApplicationController
  before_action :ensure_user_email_ownership

  def resend_confirmation
    flash[:success] = translation(:resend_confirmation)
    @user_email.send_confirmation_email
    redirect_to edit_my_account_path
  end

  # Confirming merges the email into the account, so the emailed GET only renders a form that
  # posts here — a prefetch in the owner's signed in browser doesn't spend the token
  def confirm
    return unless request.post?

    if @user_email.confirm(params[:confirmation_token])
      flash[:success] = translation(:email_confirmed, user_email: @user_email.email)
    elsif @user_email.confirmed?
      flash[:notice] = translation(:already_confirmed, user_email: @user_email.email)
    else
      flash[:error] = translation(:incorrect_token, user_email: @user_email.email)
    end
    redirect_to edit_my_account_path
  end

  def make_primary
    if @user_email.confirmed?
      @user_email.make_primary
      flash[:success] = translation(:email_has_been_made_primary, user_email: @user_email.email)
    else
      flash[:notice] = translation(:confirm_email_first, user_email: @user_email.email)
    end
    redirect_to edit_my_account_path
  end

  def destroy
    if @user_email.primary?
      flash[:notice] = translation(:email_primary, user_email: @user_email.email)
    elsif @user_email.user.user_emails.count < 2
      flash[:notice] = translation(:only_email, user_email: @user_email.email)
    else
      flash[:success] = translation(:email_removed, user_email: @user_email.email)
      @user_email.destroy
    end
    redirect_to edit_my_account_path
  end

  private

  def ensure_user_email_ownership
    unless current_user && current_user.user_emails.pluck(:id).include?(params[:id].to_i)
      flash[:error] = translation(:you_must_be_signed_in)
      redirect_to(user_root_url) && return
    end
    @user_email = current_user.user_emails.find(params[:id])
  end
end
