class UserPhonesController < ApplicationController
  before_action :authenticate_user
  before_action :find_user_phone

  def update
    if params[:resend_confirmation].present?
      if @user_phone.confirmed?
        flash[:error] = "That phone number is already confirmed!"
      else
        @user_phone.resend_confirmation_if_reasonable!
        flash[:success] = "Verification code sent!"
      end
    elsif params[:confirmation_code]
      if @user_phone.confirmation_code == params[:confirmation_code]
        if @user_phone.expired?
          flash[:error] = "Verification code expired. We've sent a new code, please verify it in the next 30 minutes"
          @user_phone.resend_confirmation_if_reasonable!
        else
          @user_phone.confirm!
          flash[:success] = "Phone number verified! Thank you"
        end
      else
        flash[:error] = "Incorrect verification code"
      end
    else
      flash[:error] = "Unknown phone verification action"
    end
    redirect_back(fallback_location: my_account_url)
  end

  def destroy
    @user_phone.destroy
    flash[:success] = "Phone removed from your account"
    redirect_back(fallback_location: my_account_url)
  end

  private

  def find_user_phone
    @user_phone = current_user.user_phones.find(params[:id])
  end
end
