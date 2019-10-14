class OwnershipsController < ApplicationController
  before_filter :find_ownership
  before_filter -> { authenticate_user(no_user_flash_msg) }

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

  # Return the translation key and, optionally, any keyword args to provide to
  # `authenticate_user`.
  def no_user_flash_msg
    return :cannot_find_bike if @ownership&.bike.blank?

    if @ownership&.user.present?
      [:owner_already_has_account, { bike_type: @ownership.bike.type }]
    else
      [:create_account_to_claim, { bike_type: @ownership.bike.type }]
    end
  end

  private

  def find_ownership
    @ownership = Ownership.find(params[:id])
  end
end
