# frozen_string_literal: true

class Admin::StravaGearsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_strava_gears.includes(strava_integration: :user).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  helper_method :matching_strava_gears

  protected

  def sortable_columns
    %w[created_at updated_at gear_type strava_integration_id total_distance_kilometers]
  end

  def sortable_opts
    "strava_gears.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    Time.at(1738368000) # 2025-02-01
  end

  def matching_strava_gears
    strava_gears = StravaGear.all

    if params[:user_id].present?
      strava_gears = strava_gears.joins(:strava_integration).where(strava_integrations: {user_id: user_subject&.id || params[:user_id]})
    end

    if params[:search_strava_integration_id].present?
      strava_gears = strava_gears.where(strava_integration_id: params[:search_strava_integration_id])
    end

    if params[:search_gear_type].present?
      strava_gears = strava_gears.where(gear_type: params[:search_gear_type])
    end

    @time_range_column = "updated_at" if sort_column == "updated_at"
    @time_range_column ||= "created_at"
    strava_gears.where(@time_range_column => @time_range)
  end
end
