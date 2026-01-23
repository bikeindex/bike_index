class MyAccounts::MessagesController < ApplicationController
  include Sessionable

  before_action :authenticate_user_for_my_accounts_controller

  def index
    params[:page] || 1
    @per_page = permitted_per_page(default: 50)
    @marketplace_messages = matching_marketplace_messages
    @pagy, @marketplace_messages = pagy(matching_marketplace_messages
      .includes(:marketplace_listing, :sender, :receiver, :initial_record), limit: @per_page, page: permitted_page)
  end

  def show
    if new_message_to_self?
      flash[:notice] = translation(:sorry_that_is_you)
      redirect_back(fallback_location: bike_path(@marketplace_listing.item_id)) && return
    end

    @marketplace_messages = matching_marketplace_thread
    @initial_record = @marketplace_messages.first

    @marketplace_listing = if @marketplace_messages.none?
      decoded_marketplace_listing
    else
      @initial_record.marketplace_listing
    end

    # raises if can't see
    @can_send_message = verify_can_see_message!(@marketplace_listing, @initial_record)

    if @can_send_message
      @marketplace_message = MarketplaceMessage.new(marketplace_listing_id: @marketplace_listing.id, initial_record_id: @initial_record&.id)
    end
  end

  def create
    @marketplace_message = MarketplaceMessage.new(permitted_params)

    @marketplace_listing ||= @marketplace_message.marketplace_listing # enables rendering!

    # raises if can't see
    @can_send_message = verify_can_see_message!(@marketplace_listing, @marketplace_message)

    if !@marketplace_message.can_send?
      flash[:error] = translation(:can_not_send_message)
      render :show
    elsif @marketplace_message.ignored_duplicate? || @marketplace_message.save
      flash[:success] = translation(:message_sent)
      redirect_to my_account_messages_path
    else
      render :show
    end
  end

  private

  def permitted_params
    params.require(:marketplace_message)
      .permit(:initial_record_id, :marketplace_listing_id, :subject, :body)
      .merge(sender_id: current_user.id)
  end

  def verify_can_see_message!(marketplace_listing, marketplace_message)
    raise ActiveRecord::RecordNotFound unless MarketplaceMessage.can_see_messages?(
      user: current_user, marketplace_listing:, marketplace_message:
    )

    MarketplaceMessage.can_send_message?(user: current_user, marketplace_listing:, marketplace_message:)
  end

  def decoded_marketplace_listing
    MarketplaceListing.find(
      MarketplaceMessage.decoded_marketplace_listing_id(user: current_user, id: params[:id])
    )
  end

  def matching_marketplace_thread
    MarketplaceMessage.thread_for!(user: current_user, id: params[:id])
  end

  def matching_marketplace_messages
    MarketplaceMessage.threads_for_user(current_user)
  end

  def new_message_to_self?
    marketplace_listing_id = MarketplaceMessage.decoded_marketplace_listing_id(id: params[:id])
    return false if marketplace_listing_id.blank?

    @marketplace_listing = MarketplaceListing.find_by_id(marketplace_listing_id)
    @marketplace_listing&.seller_id == current_user.id
  end
end
