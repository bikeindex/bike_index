class Admin::LoggedSearchesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 10
    @pagy, @logged_searches =
      pagy(matching_logged_searches
        .reorder("logged_searches.#{sort_column} #{sort_direction}")
        .includes(:organization, :user), limit: @per_page, page: permitted_page)
  end

  helper_method :matching_logged_searches, :special_endpoints

  private

  def sortable_columns
    %w[request_at created_at duration_ms endpoint stolenness ip_address organization_id user_id
      serial_normalized page].freeze
  end

  def earliest_period_date
    LoggedSearch.minimum(:request_at) || Time.current - 1.day
  end

  def special_endpoints
    %w[not_web_bikes organized]
  end

  def matching_logged_searches
    logged_searches = LoggedSearch.all

    if special_endpoints.include?(params[:search_endpoint])
      @endpoint = params[:search_endpoint]
      logged_searches = case @endpoint
      when "not_web_bikes" then logged_searches.where.not(endpoint: :web_bikes)
      when "organized" then logged_searches.organized
      end
    elsif LoggedSearch.endpoints.key?(params[:search_endpoint])
      @endpoint = params[:search_endpoint]
      logged_searches = logged_searches.where(endpoint: @endpoint)
    else
      @endpoint = "all"
    end

    @serial = InputNormalizer.boolean(params[:search_serial])
    logged_searches = logged_searches.serial if @serial

    @includes_query = InputNormalizer.boolean(params[:search_includes_query])
    logged_searches = logged_searches.includes_query if @includes_query

    @with_location = InputNormalizer.boolean(params[:search_with_location])
    logged_searches = logged_searches.with_location if @with_location

    if params[:search_ip_address].present?
      logged_searches = logged_searches.where(ip_address: params[:search_ip_address])
    end
    if params[:user_id].present?
      logged_searches = logged_searches.where(user_id: params[:user_id])
    end
    if params[:organization_id].present?
      logged_searches = logged_searches.where(organization_id: params[:organization_id])
    end

    logged_searches = logged_searches.where.not(user_id: nil) if sort_column == "user_id"
    logged_searches = logged_searches.where.not(organization_id: nil) if sort_column == "organization_id"
    logged_searches = logged_searches.where.not(page: nil) if sort_column == "page"

    @time_range_column = sort_column if %w[created_at updated_at].include?(sort_column)
    @time_range_column ||= "request_at"
    logged_searches.where(@time_range_column => @time_range)
  end
end
