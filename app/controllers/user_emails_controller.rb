class UserEmailsController < ApplicationController
  def resend_confirmation
    unless current_user && current_user.user_emails.pluck(:id).include?(params[:id].to_i)
      flash[:error] = "That's not your additional email! Email contact@bikeindex.org if this doesn't make sense."
      redirect_to user_root_url and return
    end
    flash[:success] = 'Email confirmation re-sent'
    UserEmail.find(params[:id]).send_confirmation_email
    redirect_to my_account_path
  end

  def confirm
    unless current_user && current_user.user_emails.pluck(:id).include?(params[:id].to_i)
      flash[:info] = "That's not your additional email! Please sign in as the user you want to add that email to. Email contact@bikeindex.org if this doesn't make sense."
      redirect_to user_root_url and return
    end
    user_email = UserEmail.find(params[:id])
    if user_email.confirm(params[:confirmation_token])
      flash[:success] = "#{user_email.email} has been confirmed and added to your account. It may take up to an hour for the attributes from your account to fully merge in, please be patient."
    elsif user_email.confirmed
      flash[:info] = "#{user_email.email} is already confirmed. It may take up to an hour for the attributes from your account to fully merge in, please be patient."
    else
      flash[:error] = "Incorrect token for #{user_email.email}. Try resending the confirmation email"
    end
    redirect_to my_account_path
  end

  def destroy
    unless current_user && current_user.user_emails.pluck(:id).include?(params[:id].to_i)
      flash[:info] = "That's not your additional email! Email contact@bikeindex.org if this doesn't make sense."
      redirect_to user_root_url and return
    end
    user_email = UserEmail.find(params[:id])
    if user_email.confirmed
      flash[:info] = "#{user_email.email} is confirmed and can't be deleted. Email contact@bikeindex.org for help."
    else
      flash[:success] = "#{user_email.email} deleted."
      user_email.destroy
    end
    redirect_to my_account_path
  end
end
