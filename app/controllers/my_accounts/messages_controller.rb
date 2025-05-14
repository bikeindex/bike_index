class MyAccounts::MessagesController < ApplicationController
  include Sessionable
  before_action :authenticate_user_for_my_accounts_controller
  before_action :enable_importmaps

  def index
    params[:page] || 1
    @per_page = params[:per_page] || 50
    @marketplace_messages = matching_marketplace_messages
    @pagy, @marketplace_messages = pagy(matching_marketplace_messages
      .includes(:marketplace_listing, :sender, :receiver, :item, :intial_record), limit: @per_page)
  end

  def show
    @marketplace_messages = matching_marketplace_thread
    @initial_record = @marketplace_messages.first

    @marketplace_listing = if @marketplace_messages.none?
      MarketplaceListing.find(decoded_marketplace_listing_id)
    else
      @initial_record.marketplace_listing
    end

    @can_send_message = MarketplaceMessage.can_send_message?(user: current_user,
      marketplace_listing: @marketplace_listing, marketplace_message: @initial_record)

    if @can_send_message
      @marketplace_message = MarketplaceMessage.new(marketplace_listing_id: @marketplace_listing.id)
    end
  end

  def create
    @marketplace_message = MarketplaceMessage.new(permitted_params)

    if @marketplace_message.save
      flash[:success] = "Message sent"
      redirect_to my_account_messages_path
    else
      render :new
    end
  end

  private

  def permitted_params
    params.require(:marketplace_message).permit(:status)
  end

  def decoded_marketplace_listing_id
    MarketplaceMessage.decoded_marketplace_listing_id(user: current_user, id: params[:id])
  end

  def matching_marketplace_thread
    MarketplaceMessage.thread_for(user: current_user, id: params[:id])
  end

  def matching_marketplace_messages
    MarketplaceMessage.threads_for_user(current_user)
  end
end
