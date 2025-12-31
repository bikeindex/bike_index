class SalesController < ApplicationController
  before_action :build_and_authorize_sale!

  def new
    @bike = @sale.item
  end

  def create
    @sale.attributes = permitted_create_params

    if @sale.save
      flash[:success] = "#{@sale.item_cycle_type} marked sold!"
      redirect_to(bike_path(@sale.item_id))
    else
      render :new
    end
  end

  private

  def build_and_authorize_sale!
    if current_user.present?
      @sale, error_message = Sale.build_and_authorize(user: current_user, marketplace_message_id:)
      return if error_message.blank?

      flash[:error] = error_message
      redirect_back(fallback_location: user_root_url) && return
    end

    if @ownership&.bike.blank?
      store_return_and_authenticate_user(translation_key: :cannot_find_bike)
    else
      store_return_and_authenticate_user
    end
  end

  def marketplace_message_id
    params[:marketplace_message_id] || params.dig(:sale, :marketplace_message_id)
  end

  def permitted_create_params
    params.require(:sale).permit(:amount, :currency)
  end
end
