# == Schema Information
#
# Table name: strava_integrations
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  access_token                :text             not null
#  activities_downloaded_count :integer          default(0), not null
#  athlete_activity_count      :integer
#  athlete_gear                :jsonb
#  refresh_token               :text             not null
#  status                      :integer          default("pending"), not null
#  token_expires_at            :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  athlete_id                  :string
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_strava_integrations_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class StravaIntegration < ApplicationRecord
  STATUS_ENUM = {pending: 0, syncing: 1, synced: 2, error: 3}.freeze

  belongs_to :user
  has_many :strava_activities, dependent: :destroy
  has_many :strava_gear_associations, dependent: :destroy

  enum :status, STATUS_ENUM

  validates :access_token, presence: true
  validates :refresh_token, presence: true

  def sync_progress_percent
    return 0 if athlete_activity_count.blank? || athlete_activity_count.zero?
    [(activities_downloaded_count.to_f / athlete_activity_count * 100).round, 100].min
  end

  def gear_names
    return [] if athlete_gear.blank?
    athlete_gear.map { |g| g["name"] }.compact
  end

  def show_gear_link?
    synced? && athlete_gear.present?
  end

  def cycling_gear_ids
    return [] if athlete_gear.blank?
    athlete_gear.select { |g| g["primary"] == true || g["resource_state"].present? }
      .map { |g| g["id"] }.compact
  end
end
