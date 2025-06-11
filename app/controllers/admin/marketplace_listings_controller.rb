class Admin::MarketplaceListingsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_marketplace_listings.includes(:seller, :item, :buyer, :address_record)
        .reorder("marketplace_listings.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  helper_method :matching_marketplace_listings, :searchable_statuses

  protected

  def sortable_columns
    %w[created_at updated_at published_at end_at item_id amount_cents condition status seller_id buyer_id]
  end

  def searchable_statuses
    MarketplaceListing.statuses.keys.map(&:to_s)
  end

  def matching_marketplace_listings
    marketplace_listings = MarketplaceListing
    @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
    marketplace_listings = marketplace_listings.send(@status) if @status.present?

    @time_range_column = sort_column if %w[updated_at published_at end_at].include?(sort_column)
    @time_range_column ||= "created_at"
    marketplace_listings.where(@time_range_column => @time_range)
  end
end
