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

  def show
  end

  def new
  end

  def create
  end

  private

  def matching_marketplace_messages
    marketplace_messages = MarketplaceMessage.threads_for_user(current_user)

    marketplace_messages
  end
end
