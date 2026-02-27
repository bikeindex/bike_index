# frozen_string_literal: true

class Admin::StravaRequestsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_strava_requests.reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  helper_method :matching_strava_requests

  protected

  def sortable_columns
    %w[updated_at created_at requested_at request_type response_status strava_integration_id]
  end

  def sortable_opts
    "strava_requests.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    Time.at(1738368000) # 2025-02-01
  end

  def matching_strava_requests
    strava_requests = StravaRequest.all

    if params[:search_request_type].present?
      strava_requests = strava_requests.where(request_type: params[:search_request_type])
    end

    if params[:search_response_status].present?
      strava_requests = case params[:search_response_status]
      when "pending_or_success" then strava_requests.where(response_status: StravaRequest::PENDING_OR_SUCCESS)
      when "not_successful" then strava_requests.where(response_status: StravaRequest::NOT_SUCCESSFUL)
      else strava_requests.where(response_status: params[:search_response_status])
      end
    end

    if params[:search_strava_integration_id].present?
      strava_requests = strava_requests.where(strava_integration_id: params[:search_strava_integration_id])
    end

    if params[:user_id].present?
      strava_requests = strava_requests.where(user_id: user_subject&.id || params[:user_id])
    end

    @time_range_column = sort_column if %w[updated_at requested_at].include?(sort_column)
    @time_range_column ||= "created_at"
    strava_requests.where(@time_range_column => @time_range)
  end
end
