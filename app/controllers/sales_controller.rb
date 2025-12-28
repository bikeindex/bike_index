class SalesController < ApplicationController
  before_action :find_ownership
  before_action :authorize_user_and_set_flash

  def new
    @bike = Bike.unscoped.find(@ownership.bike_id)
    @sale = Sale.new(ownership_id: @ownership.id)
  end

  def create
    @sale = Sale.new(permitted_create_params)

    if @sale.save
      flash[:success] = "#{@ownership.bike_type} marked sold!"
      redirect_to(bike_path(@ownership.bike_id))
    else
      render :new
    end
  end

  private

  def find_ownership
    ownership_id = params[:ownership_id] || params.dig(:sale, :ownership_id)
    @ownership = Ownership.find(ownership_id)
  end

  def authorize_user_and_set_flash
    if current_user.present?
      return if @ownership&.user_id == current_user.id

      flash[:error] = "You don't have permission to sell that #{@ownership&.bike_type || "Bike"}"
      redirect_back(fallback_location: user_root_url) && return
    end

    if @ownership&.bike.blank?
      store_return_and_authenticate_user(translation_key: :cannot_find_bike)
    else
      store_return_and_authenticate_user
    end
  end

  def permitted_create_params
    params.require(:sale).permit(:amount, :currency, :marketplace_message_id, :ownership_id)
      .merge(seller_id: current_user.id)
  end
end
