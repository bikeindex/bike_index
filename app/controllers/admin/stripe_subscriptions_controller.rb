class Admin::StripeSubscriptionsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_stripe_subscriptions.includes(:user, :stripe_price, :payments).reorder("stripe_subscriptions.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  helper_method :matching_stripe_subscriptions

  protected

  def sortable_columns
    %w[created_at stripe_price_stripe_id start_at end_at user_id stripe_status]
  end

  def matching_stripe_subscriptions
    StripeSubscription
  end
end
