class SalesController < ApplicationController
  before_action :build_and_authorize_sale!

  def new
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @sale.attributes = permitted_create_params

    if @sale.save
      flash[:success] = "#{@sale.item_cycle_type.titleize} marked sold and transferred!"

      # Direct to my_account because it takes a little while for the sale to process
      redirect_to(my_account_path)
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
