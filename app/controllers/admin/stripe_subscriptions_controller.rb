class Admin::StripeSubscriptionsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(
      matching_stripe_subscriptions.includes(:user, :stripe_price, :payments).reorder("stripe_subscriptions.#{sort_column} #{sort_direction}"),
      limit: @per_page,
      page: permitted_page
    )
  end

  helper_method :matching_stripe_subscriptions

  protected

  def sortable_columns
    %w[created_at stripe_price_stripe_id start_at end_at user_id stripe_status]
  end

  def matching_stripe_subscriptions
    stripe_subscriptions = StripeSubscription

    @time_range_column = sort_column if %w[start_at end_at].include?(sort_column)
    @time_range_column ||= "created_at"
    stripe_subscriptions.where(@time_range_column => @time_range)
  end
end
