class Admin::StravaIntegrationsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_strava_integrations.includes(:user).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  def show
    @strava_integration = StravaIntegration.unscoped.find(params[:id])
  end

  helper_method :matching_strava_integrations

  protected

  def sortable_columns
    %w[created_at user_id status activities_downloaded_count]
  end

  def sortable_opts
    "strava_integrations.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    Time.at(1738368000) # 2025-02-01
  end

  def matching_strava_integrations
    strava_integrations = StravaIntegration.unscoped

    if params[:user_id].present?
      strava_integrations = strava_integrations.where(user_id: user_subject&.id || params[:user_id])
    end

    if params[:search_status].present?
      strava_integrations = strava_integrations.where(status: params[:search_status])
    end

    strava_integrations.where(created_at: @time_range)
  end
end
