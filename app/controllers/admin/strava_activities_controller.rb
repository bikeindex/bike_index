class Admin::StravaActivitiesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_strava_activities.includes(:strava_integration).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  helper_method :matching_strava_activities

  protected

  def sortable_columns
    %w[created_at start_date activity_type distance_meters strava_integration_id]
  end

  def sortable_opts
    "strava_activities.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    Time.at(1738368000) # 2025-02-01
  end

  def matching_strava_activities
    strava_activities = StravaActivity.all

    if params[:search_strava_integration_id].present?
      strava_activities = strava_activities.where(strava_integration_id: params[:search_strava_integration_id])
    end

    if params[:search_activity_type].present?
      strava_activities = strava_activities.where(activity_type: params[:search_activity_type])
    end

    strava_activities.where(created_at: @time_range)
  end
end
