class Admin::SalesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_sales.includes(:seller, :ownership).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  def show
    @sale = Sale.find(params[:id])
    @marketplace_listing = @sale.marketplace_listing
  end

  helper_method :matching_sales

  protected

  def sortable_columns
    %w[created_at sold_at amount_cents sold_via seller_id ownership_id]
  end

  def sortable_opts
    "sales.#{sort_column} #{sort_direction}"
  end

  def matching_sales
    sales = Sale.all

    if params[:search_bike_id].present?
      @bike = Bike.unscoped.find_by(id: params[:search_bike_id])
      sales = sales.joins(:ownership).where(ownerships: {bike_id: params[:search_bike_id]})
    end

    if params[:search_marketplace_listing_id].present?
      @marketplace_listing = MarketplaceListing.find_by(id: params[:search_marketplace_listing_id])
      sales = sales.joins(:marketplace_listing)
        .where(marketplace_listings: {id: params[:search_marketplace_listing_id]})
    end

    if params[:user_id].present?
      sales = sales.where(seller_id: user_subject&.id || params[:user_id])
    end

    if params[:search_sold_via].present?
      sales = sales.where(sold_via: params[:search_sold_via])
    end

    sales.where(created_at: @time_range)
  end
end
