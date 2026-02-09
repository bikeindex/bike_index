# == Schema Information
#
# Table name: strava_requests
# Database name: analytics
#
#  id                    :bigint           not null, primary key
#  endpoint              :string           not null
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
  REQUEST_TYPE_ENUM = {fetch_athlete: 0, fetch_athlete_stats: 1, list_activities: 2, fetch_activity: 3}.freeze
  RESPONSE_STATUS_ENUM = {pending: 0, success: 1, error: 2, rate_limited: 3, token_refresh_failed: 4}.freeze

  belongs_to :user

  enum :request_type, REQUEST_TYPE_ENUM
  enum :response_status, RESPONSE_STATUS_ENUM

  validates :strava_integration_id, presence: true
  validates :endpoint, presence: true

  scope :unprocessed, -> { where(requested_at: nil).order(:created_at) }

  def self.next_pending
    unprocessed.first
  end
end
