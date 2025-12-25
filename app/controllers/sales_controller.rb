class SalesController < ApplicationController
  before_action :find_ownership
  before_action :authenticate_user_and_set_flash

  def new
    pp "0000000"
    @bike = Bike.unscoped.find(@ownership.bike_id)
  end

  private

  def authenticate_user_and_set_flash
    if @ownership&.bike.blank?
      store_return_and_authenticate_user(translation_key: :cannot_find_bike)
    else
      store_return_and_authenticate_user
    end
  end

  def find_ownership
    @ownership = Ownership.find(params[:ownership_id])
  end
end
