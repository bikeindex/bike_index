class Admin::MarketplaceMessagesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_marketplace_messages.includes(:marketplace_listing, :sender, :receiver).reorder("marketplace_messages.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def show
    @marketplace_message = MarketplaceMessage.find(params[:id])
    @marketplace_listing = @marketplace_message.marketplace_listing
  end

  helper_method :matching_marketplace_messages

  protected

  def sortable_columns
    %w[created_at marketplace_listing kind initial_record_id sender_id receiver_id]
  end

  def matching_marketplace_messages
    marketplace_messages = MarketplaceMessage

    marketplace_messages.where(created_at: @time_range)
  end
end
