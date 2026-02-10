# frozen_string_literal: true

# == Schema Information
#
# Table name: strava_activities
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  activity_timezone           :string
#  activity_type               :string
#  description                 :text
#  distance_meters             :float
#  kudos_count                 :integer
#  moving_time_seconds         :integer
#  muted                       :boolean          default(FALSE)
#  photos                      :jsonb
#  private                     :boolean          default(FALSE)
#  segment_locations           :jsonb
#  sport_type                  :string
#  start_date                  :datetime
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
  scope :enriched, -> { where.not(segment_locations: nil) }
  scope :un_enriched, -> { where(segment_locations: nil) }
  scope :activities_to_enrich, -> { cycling.un_enriched }

  class << self
    def activity_types
      @activity_types ||= distinct.pluck(:activity_type).compact.sort
    end

    def create_or_update_from_summary(strava_integration, summary)
      attrs = summary_attributes(summary)
      activity = strava_integration.strava_activities.find_or_initialize_by(strava_id: summary["id"].to_s)
      activity.update!(attrs)
      activity.update_gear_association_distance!
      activity
    end

    def detail_attributes(detail)
      photos_data = detail.dig("photos", "primary")
      photos = if photos_data
        urls = photos_data["urls"] || {}
        [{id: photos_data["unique_id"], urls:}]
      else
        []
      end

      segments = detail["segment_efforts"]
      segment_locations = if segments.present?
        {
          cities: segments.filter_map { |se| se.dig("segment", "city").presence }.uniq,
          states: segments.filter_map { |se| se.dig("segment", "state").presence }.uniq,
          countries: segments.filter_map { |se| se.dig("segment", "country").presence }.uniq
        }
      else
        {}
      end

      {
        description: detail["description"],
        photos:,
        segment_locations:,
        muted: detail["muted"],
        kudos_count: detail["kudos_count"]
      }
    end

    private

    def summary_attributes(summary)
      start_date = Binxtils::TimeParser.parse(summary["start_date"])
      {
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
        activity_timezone: summary["timezone"],
        start_date:
      }
    end
  end

  def cycling?
    CYCLING_TYPES.include?(activity_type)
  end

  def enriched?
    !segment_locations.nil?
  end

  def calculated_gear_name
    return nil if gear_id.blank?
    strava_integration.strava_gears.find_by(strava_gear_id: gear_id)&.strava_gear_name || gear_id
  end

  def distance_miles
    return nil if distance_meters.blank?
    (distance_meters / 1609.344).round(2)
  end

  def distance_km
    return nil if distance_meters.blank?
    (distance_meters / 1000.0).round(2)
  end

  def update_from_detail(detail)
    update(self.class.detail_attributes(detail))
    update_gear_association_distance!
  end

  def update_gear_association_distance!
    return if gear_id.blank?

    strava_integration.strava_gears.where(strava_gear_id: gear_id).find_each do |ga|
      ga.update_total_distance!
    end
  end
end
