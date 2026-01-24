class Admin::MarketplaceMessagesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(
      matching_marketplace_messages.includes(:marketplace_listing, :sender, :receiver).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page
    )
  end

  def show
    @marketplace_message = MarketplaceMessage.find(params[:id])
    @marketplace_listing = @marketplace_message.marketplace_listing
    @marketplace_messages_thread = @marketplace_message.messages_in_thread
  end

  helper_method :matching_marketplace_messages

  protected

  def sortable_columns
    %w[created_at marketplace_listing kind amount_cents initial_record_id sender_id receiver_id
       messages_prior_count]
  end

  def sortable_opts
    if sort_column == "amount_cents"
      "marketplace_listing.#{sort_column} #{sort_direction}"
    else
      "marketplace_messages.#{sort_column} #{sort_direction}"
    end
  end

  def matching_marketplace_messages
    marketplace_messages = MarketplaceMessage

    if params[:search_bike_id].present?
      @bike = Bike.unscoped.find_by(id: params[:search_bike_id])
      marketplace_messages = marketplace_messages.includes(:marketplace_listing)
        .where(marketplace_listings: {item_type: "Bike", item_id: params[:search_bike_id]})
    end
    if params[:search_marketplace_listing_id].present?
      marketplace_messages = marketplace_messages.where(marketplace_listing_id: params[:search_marketplace_listing_id])
      @marketplace_listing = MarketplaceListing.find_by(id: params[:search_marketplace_listing_id])
    end

    if params[:user_id].present?
      marketplace_messages = marketplace_messages.for_user(user_subject&.id || params[:user_id])
    end

    marketplace_messages.where(created_at: @time_range)
  end
end
