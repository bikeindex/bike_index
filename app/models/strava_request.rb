# frozen_string_literal: true

# == Schema Information
#
# Table name: strava_requests
# Database name: analytics
#
#  id                    :bigint           not null, primary key
#  parameters            :jsonb
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
#  index_strava_requests_on_strava_integration_id_and_requested_at  (strava_integration_id,requested_at)
#  index_strava_requests_on_user_id                                 (user_id)
#
class StravaRequest < AnalyticsRecord
  REQUEST_TYPE_ENUM = {
    fetch_athlete: 0,
    fetch_athlete_stats: 1,
    list_activities: 2,
    fetch_activity: 3,
    fetch_gear: 4,
    incoming_webhook: 5,
    proxy: 6
  }.freeze
  RESPONSE_STATUS_ENUM = {
    pending: 0,
    success: 1,
    error: 2,
    rate_limited: 3,
    token_refresh_failed: 4,
    integration_deleted: 5,
    skipped: 6,
    insufficient_token_privileges: 7
  }.freeze

  belongs_to :user
  belongs_to :strava_integration

  enum :request_type, REQUEST_TYPE_ENUM
  enum :response_status, RESPONSE_STATUS_ENUM

  validates :strava_integration_id, presence: true

  # Priority: incoming_webhook (5) → list_activities (2) → fetch_gear (4) → fetch_activity (3)
  PRIORITY_ORDER = [5, 2, 4, 3, 0, 1].freeze

  scope :unprocessed, -> { where(requested_at: nil).where.not(response_status: :integration_deleted).order(:id) }
  scope :priority_ordered, -> {
    reorder(Arel.sql("ARRAY_POSITION(ARRAY#{PRIORITY_ORDER}, request_type), id"))
  }

  class << self
    def next_pending(limit = 1)
      unprocessed.priority_ordered.limit(limit)
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
      latest = where.not(rate_limit: nil).order(requested_at: :desc).first
      latest.nil? ? default_rate_limit : rate_limit_from(latest.rate_limit.symbolize_keys, latest.requested_at)
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
       read_long_usage: 0}.freeze.as_json
    end

    def rate_limit_from(latest_rate_limit, latest_requested_at)
      now = Time.current.utc
      short_boundary = now.change(min: (now.min / 15) * 15, sec: 0)
      daily_boundary = now.beginning_of_day
      short_reset = short_boundary > latest_requested_at
      daily_reset = daily_boundary > latest_requested_at

      {
        short_limit: latest_rate_limit[:short_limit],
        short_usage: limit_for_rate(latest_rate_limit[:short_usage], short_reset),
        long_limit: latest_rate_limit[:long_limit],
        long_usage: limit_for_rate(latest_rate_limit[:long_usage], daily_reset),
        read_short_limit: latest_rate_limit[:read_short_limit],
        read_short_usage: limit_for_rate(latest_rate_limit[:read_short_usage], short_reset),
        read_long_limit: latest_rate_limit[:read_long_limit],
        read_long_usage: limit_for_rate(latest_rate_limit[:read_long_usage], daily_reset)
      }.as_json.compact
    end

    def limit_for_rate(limit, was_reset)
      was_reset ? 0 : limit
    end
  end

  def skip_request?
    false # TODO: Make this skip if it's already been requested - specifically, a proxy
  end

  def looks_like_last_page?(per_page: nil)
    return false unless list_activities?

    per_page ||= Integrations::StravaClient::ACTIVITIES_PER_PAGE
    page = parameters["page"]&.to_i || 1
    expected_pages = (strava_integration.athlete_activity_count.to_i > 0) ?
      (strava_integration.athlete_activity_count.to_f / per_page).ceil : 1
    page >= expected_pages
  end

  def update_from_response(response, re_enqueue_if_rate_limited: false, raise_on_error: true)
    update!(requested_at: Time.current,
      response_status: status_from_response(response),
      rate_limit: self.class.parse_rate_limit(response&.headers))

    if re_enqueue_if_rate_limited && rate_limited?
      StravaRequest.create!(user_id:, strava_integration_id:, request_type:, parameters:)
    elsif error? && raise_on_error
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
      :token_refresh_failed
    elsif insufficient_token_privileges_response?(response)
      :insufficient_token_privileges
    else
      :error
    end
  end

  # IDK, sort of a guess - because Strava responds with a 404 :/
  # looks like errors field is "path" and the code is "invalid" for legit 404s
  def insufficient_token_privileges_response?(response)
    return false if response.status != 404

    response_error = response.body["errors"].first
    response_error&.dig("code") == "not found" && response_error&.dig("field").blank?
  end
end
