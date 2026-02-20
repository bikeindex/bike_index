# frozen_string_literal: true

class Admin::StravaActivitiesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_strava_activities.includes(strava_integration: %i[user strava_gears]).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  helper_method :matching_strava_activities

  protected

  def sortable_columns
    %w[created_at updated_at start_date activity_type distance_meters strava_integration_id]
  end

  def sortable_opts
    "strava_activities.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    return Time.at(1262304000) if sort_column == "start_date" # 2010-01-01
    Time.at(1738368000) # 2025-02-01
  end

  def matching_strava_activities
    strava_activities = StravaActivity.all

    if params[:user_id].present?
      strava_activities = strava_activities.joins(:strava_integration).where(strava_integrations: {user_id: user_subject&.id || params[:user_id]})
    end

    if params[:search_strava_integration_id].present?
      strava_activities = strava_activities.where(strava_integration_id: params[:search_strava_integration_id])
    end

    @with_gear = Binxtils::InputNormalizer.boolean(params[:search_with_gear])
    strava_activities = strava_activities.with_gear if @with_gear

    @searched_activity_type = params[:search_activity_type]
    if @searched_activity_type.present?
      strava_activities = strava_activities.where(activity_type: @searched_activity_type)
    end

    @searched_enriched = params[:search_enriched]
    if @searched_enriched == "true"
      strava_activities = strava_activities.enriched
    elsif @searched_enriched == "false"
      strava_activities = strava_activities.not_enriched
    end

    @time_range_column = sort_column if %w[updated_at start_date].include?(sort_column)
    @time_range_column ||= "created_at"
    strava_activities.where(@time_range_column => @time_range)
  end
end
