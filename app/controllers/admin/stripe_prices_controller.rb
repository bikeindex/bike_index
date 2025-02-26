class Admin::StripePricesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_stripe_prices.reorder("stripe_prices.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  helper_method :matching_stripe_prices

  protected

  def sortable_columns
    %w[created_at membership_level amount_cents currency_enum interval]
  end

  def matching_stripe_prices
    StripePrice
  end
end
