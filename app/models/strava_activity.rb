# == Schema Information
#
# Table name: strava_activities
# Database name: primary
#
#  id                    :bigint           not null, primary key
#  activity_type         :string
#  description           :text
#  distance              :float
#  gear_name             :string
#  location_city         :string
#  location_country      :string
#  location_state        :string
#  photos                :jsonb
#  start_date            :datetime
#  start_latitude        :float
#  start_longitude       :float
#  title                 :string
#  year                  :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  gear_id               :string
#  strava_id             :string           not null
#  strava_integration_id :bigint           not null
#
# Indexes
#
#  index_strava_activities_on_strava_integration_id                (strava_integration_id)
#  index_strava_activities_on_strava_integration_id_and_strava_id  (strava_integration_id,strava_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (strava_integration_id => strava_integrations.id)
#
class StravaActivity < ApplicationRecord
  CYCLING_TYPES = %w[
    Ride
    MountainBikeRide
    GravelRide
    EBikeRide
    EMountainBikeRide
    VirtualRide
    Handcycle
    Velomobile
  ].freeze

  belongs_to :strava_integration

  validates :strava_id, presence: true
  validates :strava_id, uniqueness: {scope: :strava_integration_id}

  scope :cycling, -> { where(activity_type: CYCLING_TYPES) }

  def cycling?
    CYCLING_TYPES.include?(activity_type)
  end

  def distance_miles
    return nil if distance.blank?
    (distance / 1609.344).round(2)
  end

  def distance_km
    return nil if distance.blank?
    (distance / 1000.0).round(2)
  end
end
