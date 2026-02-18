# frozen_string_literal: true

# == Schema Information
#
# Table name: strava_activities
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  activity_type               :string
#  average_speed               :float
#  description                 :text
#  distance_meters             :float
#  kudos_count                 :integer
#  moving_time_seconds         :integer
#  photos                      :jsonb
#  private                     :boolean          default(FALSE)
#  segment_locations           :jsonb
#  sport_type                  :string
#  start_date                  :datetime
#  strava_data                 :jsonb
#  suffer_score                :float
#  timezone                    :string
#  title                       :string
#  total_elevation_gain_meters :float
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
  scope :with_gear, -> { where.not(gear_id: nil) }

  class << self
    def activity_types
      @activity_types ||= distinct.pluck(:activity_type).compact.sort
    end

    def create_or_update_from_strava_response(strava_integration, response)
      attrs = summary_attributes(response).merge(detail_attributes(response))
      activity = strava_integration.strava_activities.find_or_initialize_by(strava_id: response["id"].to_s)
      activity.update!(attrs)
      activity
    end

    def detail_attributes(detail)
      return {} if (detail.keys & %w[segment_efforts description]).none?

      photo_url = detail.dig("photos", "primary", "urls", "600")
      photos = {photo_url:, photo_count: detail.dig("photos", "count") || 0}

      {
        description: detail["description"],
        average_speed: detail["average_speed"],
        suffer_score: detail["suffer_score"],
        photos:,
        segment_locations: segment_locations_for(detail["segment_efforts"]),
        kudos_count: detail["kudos_count"],
        strava_data: strava_data_from(detail)
      }
    end

    private

    def strava_data_from(data)
      data.slice("average_heartrate", "max_heartrate", "device_name", "commute",
        "muted", "average_speed", "pr_count", "average_watts", "device_watts")
    end

    def summary_attributes(summary)
      {
        title: summary["name"],
        distance_meters: summary["distance"],
        moving_time_seconds: summary["moving_time"],
        total_elevation_gain_meters: summary["total_elevation_gain"],
        sport_type: summary["sport_type"],
        private: summary["private"],
        kudos_count: summary["kudos_count"],
        average_speed: summary["average_speed"],
        suffer_score: summary["suffer_score"],
        gear_id: summary["gear_id"],
        activity_type: summary["sport_type"] || summary["type"],
        timezone: Binxtils::TimeZoneParser.parse(summary["timezone"])&.name,
        start_date: Binxtils::TimeParser.parse(summary["start_date"]),
        strava_data: strava_data_from(summary)
      }
    end

    def segment_locations_for(segments)
      return {} if segments.blank?

      {
        cities: segments.filter_map { |se| se.dig("segment", "city").presence }.uniq,
        states: segments.filter_map { |se| se.dig("segment", "state").presence }.uniq,
        countries: segments.filter_map { |se| se.dig("segment", "country").presence }.uniq
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
    attrs = self.class.detail_attributes(detail)
    attrs[:strava_data] = (strava_data || {}).merge(attrs[:strava_data])
    update(attrs)
  end
end
