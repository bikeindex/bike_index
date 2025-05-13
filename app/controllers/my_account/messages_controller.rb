class MyAccount::MessagesController < ApplicationController
  include Sessionable
  before_action :authenticate_user_for_my_accounts_controller

  def index
    params[:page] || 1
    @per_page = params[:per_page] || 50
    @marketplace_messages = matching_marketplace_messages
    @pagy, @marketplace_messages = pagy(matching_marketplace_messages
      .includes(:marketplace_listing, :sender, :receiver, :item, :intial_record), limit: @per_page)
  end

  def new
    @marketplace_messages = matching_marketplace_thread
  end

  def create
  end

  private

  def matching_marketplace_thread
    @marketplace_listing = MarketplaceListing.find(params[:marketplace_listing_id])

    MarketplaceMessage.for(user: current_user, marketplace_listing: @marketplace_listing,
      initial_record_id: params[:initial_record_id])
  end

  def matching_marketplace_messages
    MarketplaceMessage.threads_for_user(current_user)
  end
end
