class UserPhonesController < ApplicationController
  before_action :authenticate_user

  def create
    if params[:phone].present?
      user_phone = UserPhone.add_phone_for_user_id(current_user.id, params[:phone])
      if user_phone.valid?
        flash[:success] = "Please verify your number using the code we texted you"
      else
        flash[:error] = "Unable to add phone number!"
      end
    elsif params[:confirmation_code].present?
      phone = current_user.user_phones.find_confirmation_code(params[:confirmation_code])
      if phone.present?
        phone.confirm!
      else
        flash[:error] = "Unable to verify that phone number! Maybe the code expired? Please try again"
      end
    end
    redirect_back(fallback_location: my_account_url)
  end
end
