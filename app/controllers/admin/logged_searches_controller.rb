class Admin::LoggedSearchesController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @logged_searches =
      matching_logged_searches
        .reorder("bike_sticker_updates.#{sort_column} #{sort_direction}")
        .includes(:organization, :user)
        .page(page)
        .per(@per_page)
  end

  helper_method :matching_logged_searches

  private

  def sortable_columns
    %w[request_at created_at endpoint]
  end

  def earliest_period_date
    LoggedSearch.minimum(:created_at)
  end

  def matching_logged_searches
    logged_searches = LoggedSearch.all

    if LoggedSearch.endpoints.keys.include?(params[:search_endpoint])
      @endpoint = params[:search_endpoint]
      logged_searches.where(endpoint: @endpoint)
    end

    logged_searches.where(created_at: @time_range)
  end
end
