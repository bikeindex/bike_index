# == Schema Information
#
# Table name: strava_activities
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  activity_type               :string
#  description                 :text
#  distance_meters             :float
#  gear_name                   :string
#  kudos_count                 :integer
#  moving_time_seconds         :integer
#  muted                       :boolean          default(FALSE)
#  photos                      :jsonb
#  private                     :boolean          default(FALSE)
#  segment_locations           :jsonb
#  sport_type                  :string
#  start_date                  :datetime
#  start_latitude              :float
#  start_longitude             :float
#  title                       :string
#  total_elevation_gain_meters :float
#  year                        :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  gear_id                     :string
#  strava_id                   :string           not null
#  strava_integration_id       :bigint           not null
#
# Indexes
#
#  index_strava_activities_on_strava_integration_id                (strava_integration_id)
#  index_strava_activities_on_strava_integration_id_and_strava_id  (strava_integration_id,strava_id) UNIQUE
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
    return nil if distance_meters.blank?
    (distance_meters / 1609.344).round(2)
  end

  def distance_km
    return nil if distance_meters.blank?
    (distance_meters / 1000.0).round(2)
  end

  def self.create_or_update_from_summary(strava_integration, summary)
    start_date = begin
      Time.parse(summary["start_date"])
    rescue
      nil
    end
    latlng = summary["start_latlng"]

    strava_integration.strava_activities.find_or_initialize_by(strava_id: summary["id"].to_s).tap do |activity|
      activity.assign_attributes(
        title: summary["name"],
        distance_meters: summary["distance"],
        moving_time_seconds: summary["moving_time"],
        total_elevation_gain_meters: summary["total_elevation_gain"],
        sport_type: summary["sport_type"],
        private: summary["private"],
        kudos_count: summary["kudos_count"],
        year: start_date&.year,
        gear_id: summary["gear_id"],
        activity_type: summary["sport_type"] || summary["type"],
        start_date:,
        start_latitude: latlng&.first,
        start_longitude: latlng&.last
      )
      activity.save!
    end
  end

  def update_from_detail(detail)
    update(
      description: detail["description"],
      photos: extract_photos(detail),
      segment_locations: extract_segment_locations(detail),
      gear_name: detail.dig("gear", "name"),
      muted: detail["muted"],
      kudos_count: detail["kudos_count"]
    )
  end

  private

  def extract_photos(detail)
    photos_data = detail.dig("photos", "primary")
    return [] unless photos_data

    urls = photos_data["urls"] || {}
    [{id: photos_data["unique_id"], urls:}]
  end

  def extract_segment_locations(detail)
    segments = detail["segment_efforts"]
    return {} if segments.blank?

    {
      cities: segments.filter_map { |se| se.dig("segment", "city").presence }.uniq,
      states: segments.filter_map { |se| se.dig("segment", "state").presence }.uniq,
      countries: segments.filter_map { |se| se.dig("segment", "country").presence }.uniq
    }
  end
end
