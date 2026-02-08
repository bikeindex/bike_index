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
