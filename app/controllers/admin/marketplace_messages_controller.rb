class Admin::MarketplaceMessagesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_marketplace_messages.includes(:marketplace_listing, :sender, :receiver).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page
    )
  end

  def show
    @marketplace_message = MarketplaceMessage.find(params[:id])
    @marketplace_listing = @marketplace_message.marketplace_listing
  end

  helper_method :matching_marketplace_messages

  protected

  def sortable_columns
    %w[created_at marketplace_listing kind amount_cents initial_record_id sender_id receiver_id]
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

    if params[:bike_id].present?
      @bike = Bike.unscoped.find_by(id: params[:bike_id])
      marketplace_messages = marketplace_messages.includes(:marketplace_listing)
        .where(marketplace_listings: {item_type: "Bike", item_id: params[:bike_id]})
    end

    if params[:user_id].present?
      @user = User.unscoped.find_by(id: params[:user_id])
      marketplace_messages = marketplace_messages.for_user(params[:user_id])
    end

    marketplace_messages.where(created_at: @time_range)
  end
end
