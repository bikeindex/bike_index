# frozen_string_literal: true

# == Schema Information
#
# Table name: strava_requests
# Database name: analytics
#
#  id                    :bigint           not null, primary key
#  parameters            :jsonb
#  priority              :bigint           not null
#  proxy_request         :boolean          default(FALSE), not null
#  rate_limit            :jsonb
#  request_type          :integer          not null
#  requested_at          :datetime
#  response_status       :integer          default("pending"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  strava_integration_id :bigint           not null
#  user_id               :bigint
#
# Indexes
#
#  index_strava_requests_on_requested_at_with_rate_limit            (requested_at) WHERE (rate_limit IS NOT NULL)
#  index_strava_requests_on_strava_integration_id_and_requested_at  (strava_integration_id,requested_at)
#  index_strava_requests_on_user_id                                 (user_id)
#  index_strava_requests_pending_on_integration_id_request_type     (strava_integration_id,request_type) WHERE (response_status = 0)
#
class StravaRequest < AnalyticsRecord
  REQUEST_TYPE_ENUM = {
    fetch_athlete: 0,
    fetch_athlete_stats: 1,
    list_activities: 2,
    fetch_activity: 3,
    fetch_gear: 4,
    incoming_webhook: 5,
    update_activity: 7
  }.freeze
  RESPONSE_STATUS_ENUM = {
    pending: 0,
    success: 1,
    error: 2,
    rate_limited: 3,
    token_refresh_failed: 4,
    integration_deleted: 5,
    skipped: 6,
    insufficient_token_privileges: 7,
    binx_response: 8,
    binx_response_rate_limited: 9,
    token_expired: 10
  }.freeze
  PENDING_OR_SUCCESS = %i[success pending].freeze
  NOT_SUCCESSFUL = (RESPONSE_STATUS_ENUM.keys - PENDING_OR_SUCCESS).freeze
  BINX_RESPONSE = %i[binx_response binx_response_rate_limited].freeze
  NOT_BINX_RESPONSE = (RESPONSE_STATUS_ENUM.keys - BINX_RESPONSE).freeze
  PRIORITY_MAP = {
    incoming_webhook: 1,
    fetch_athlete: 2,
    fetch_athlete_stats: 2,
    list_activities: 3,
    fetch_gear: 4,
    update_activity: 5,
    fetch_activity: 10
  }.freeze
  PRIORITY_LEVEL_MULTIPLIER = 1_000_000_000 # Based on timestamp digits

  enum :request_type, REQUEST_TYPE_ENUM
  enum :response_status, RESPONSE_STATUS_ENUM

  belongs_to :user
  belongs_to :strava_integration

  validates :strava_integration_id, presence: true

  before_validation :set_calculated_attributes, on: :create

  scope :proxy_request, -> { where(proxy_request: true) }
  scope :pending_or_success, -> { where(status: PENDING_OR_SUCCESS) }
  scope :not_successful, -> { where(status: NOT_SUCCESSFUL) }
  scope :strava_response, -> { where(response_status: NOT_BINX_RESPONSE).where.not(requested_at: nil) }
  scope :priority_ordered, -> { reorder(:priority) }

  class << self
    def next_pending(limit = 1)
      pending.priority_ordered.limit(limit)
    end

    def parse_rate_limit(headers)
      return if headers.blank?

      limit = headers["X-RateLimit-Limit"]
      usage = headers["X-RateLimit-Usage"]
      read_limit = headers["X-ReadRateLimit-Limit"]
      read_usage = headers["X-ReadRateLimit-Usage"]
      return unless limit.present? || usage.present?

      short_limit, long_limit = limit&.split(",")&.map(&:to_i)
      short_usage, long_usage = usage&.split(",")&.map(&:to_i)
      read_short_limit, read_long_limit = read_limit&.split(",")&.map(&:to_i)
      read_short_usage, read_long_usage = read_usage&.split(",")&.map(&:to_i)
      {short_limit:, short_usage:, long_limit:, long_usage:,
       read_short_limit:, read_short_usage:, read_long_limit:, read_long_usage:}.compact
    end

    def estimated_current_rate_limit
      latest = strava_response.where.not(rate_limit: nil).order(requested_at: :desc).first
      latest.nil? ? default_rate_limit : rate_limit_from(latest.rate_limit.symbolize_keys, latest.requested_at)
    end

    def most_recent_proxy_at(strava_integration_id)
      where(strava_integration_id:, proxy_request: true)
        .where.not(response_status: :pending).maximum(:updated_at)
    end

    private

    def default_rate_limit
      {short_limit: 200,
       short_usage: 0,
       long_limit: 2000,
       long_usage: 0,
       read_short_limit: 200,
       read_short_usage: 0,
       read_long_limit: 2000,
       read_long_usage: 0}.freeze
    end

    def rate_limit_from(latest_rate_limit, latest_requested_at)
      now = Time.current.utc
      short_boundary = now.change(min: (now.min / 15) * 15, sec: 0)
      daily_boundary = now.beginning_of_day
      short_reset = short_boundary > latest_requested_at
      daily_reset = daily_boundary > latest_requested_at

      {
        short_limit: latest_rate_limit[:short_limit].to_i,
        short_usage: limit_for_rate(latest_rate_limit[:short_usage].to_i, short_reset),
        long_limit: latest_rate_limit[:long_limit].to_i,
        long_usage: limit_for_rate(latest_rate_limit[:long_usage].to_i, daily_reset),
        read_short_limit: latest_rate_limit[:read_short_limit].to_i,
        read_short_usage: limit_for_rate(latest_rate_limit[:read_short_usage].to_i, short_reset),
        read_long_limit: latest_rate_limit[:read_long_limit].to_i,
        read_long_usage: limit_for_rate(latest_rate_limit[:read_long_usage].to_i, daily_reset)
      }
    end

    def limit_for_rate(limit, was_reset)
      was_reset ? 0 : limit
    end
  end

  def request_method
    parameters&.dig("method")&.upcase || "GET"
  end

  def skip_request?
    return false unless fetch_activity?

    activity = strava_integration.strava_activities.find_by(strava_id: parameters["strava_id"])
    activity.present? && !activity.re_enrich?
  end

  def looks_like_last_page?(per_page: nil)
    return false unless list_activities?

    page = parameters["page"]&.to_i || 1
    expected_pages = StravaJobs::FetchAthleteAndStats.total_pages(strava_integration.athlete_activity_count)
    page >= expected_pages
  end

  def update_from_response(response, re_enqueue_if_rate_limited_or_unavailable: false, raise_on_error: false)
    if response == :binx_response_rate_limited
      update!(requested_at: Time.current, response_status: :binx_response_rate_limited)
    else
      self.response_status = status_from_response(response)
      store_error_response(response) if error?
      update!(requested_at: Time.current, rate_limit: self.class.parse_rate_limit(response&.headers))
    end

    if token_expired?
      StravaRequest.create!(user_id:, strava_integration_id:, request_type:, proxy_request:,
        parameters: parameters.except("error_response_status"))
    elsif binx_response_rate_limited? || rate_limited? || service_unavailable?(response)
      return unless re_enqueue_if_rate_limited_or_unavailable

      StravaRequest.create!(user_id:, strava_integration_id:, request_type:, proxy_request:,
        parameters: parameters.except("error_response_status"))
    elsif error? && raise_on_error && response.status != 404
      raise "Strava API error #{response.status}: #{response.body}"
    end
  end

  private

  def status_from_response(response)
    return :success if response.blank? && incoming_webhook? # Not all incoming webhooks make requests

    if response.success?
      :success
    elsif response.status == 429
      :rate_limited
    elsif response.status == 401
      :token_expired
    elsif insufficient_token_privileges_response?(response)
      :insufficient_token_privileges
    else
      :error
    end
  end

  def service_unavailable?(response)
    response.respond_to?(:status) && response.status == 503
  end

  def store_error_response(response)
    self.parameters = (parameters || {}).merge(error_response_status: response.status)
  end

  def set_calculated_attributes
    self.user_id ||= strava_integration&.user_id
    self.priority ||= calculated_priority
  end

  def calculated_priority
    level = if proxy_request?
      0
    else
      PRIORITY_MAP[request_type.to_sym] * PRIORITY_LEVEL_MULTIPLIER
    end

    if fetch_activity? && parameters["strava_id"].present?
      level += (parameters["strava_id"].to_i / 1000)
    end

    level + Time.current.to_i / 10
  end

  # IDK, sort of a guess - because Strava responds with a 404 :/
  # looks like errors field is "path" and the code is "invalid" for legit 404s
  def insufficient_token_privileges_response?(response)
    return false if response.status != 404

    response_error = response.body["errors"].first
    response_error&.dig("code") == "not found" && response_error&.dig("field").blank?
  end
end
