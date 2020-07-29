class OwnershipsController < ApplicationController
  before_action :find_ownership
  before_action :authenticate_user_and_set_flash

  def show
    bike = Bike.unscoped.find(@ownership.bike_id)
    if @ownership.claimable_by?(current_user)
      if @ownership.current
        @ownership.mark_claimed
        flash[:success] = translation(:you_claimed_it, bike_type: bike.type)
        redirect_to edit_bike_url(bike)
      else
        flash[:error] = translation(:no_longer_your_bike, bike_type: bike.type)
        redirect_to bike_url(bike)
      end
    else
      flash[:error] = translation(:not_your_bike, bike_type: bike.type)
      redirect_to bike_url(bike)
    end
  end

  private

  def authenticate_user_and_set_flash
    if @ownership&.bike.blank?
      authenticate_user(translation_key: :cannot_find_bike)
    elsif @ownership&.user.present?
      authenticate_user(translation_key: :owner_already_has_account,
                        translation_args: {bike_type: @ownership.bike.type})
    else
      authenticate_user(translation_key: :create_account_to_claim,
                        translation_args: {bike_type: @ownership.bike.type})
    end
  end

  def find_ownership
    @ownership = Ownership.find(params[:id])
  end
end
