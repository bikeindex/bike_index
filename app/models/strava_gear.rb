# frozen_string_literal: true

# == Schema Information
#
# Table name: strava_gears
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  gear_type                   :integer
#  item_type                   :string
#  last_updated_from_strava_at :datetime
#  strava_data                 :jsonb
#  strava_gear_name            :string
#  total_distance_kilometers   :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  item_id                     :bigint
#  strava_gear_id              :string           not null
#  strava_integration_id       :bigint           not null
#
# Indexes
#
#  index_strava_gears_on_item_type_and_item_id                     (item_type,item_id) UNIQUE WHERE (item_id IS NOT NULL)
#  index_strava_gears_on_strava_integration_id                     (strava_integration_id)
#  index_strava_gears_on_strava_integration_id_and_strava_gear_id  (strava_integration_id,strava_gear_id) UNIQUE
#
class StravaGear < ApplicationRecord
  belongs_to :strava_integration
  belongs_to :item, polymorphic: true, optional: true

  validates :strava_integration, presence: true
  validates :strava_gear_id, presence: true,
    uniqueness: {scope: :strava_integration_id}
  validates :item_id, uniqueness: {scope: :item_type, message: "already has a Strava gear association"},
    allow_nil: true

  GEAR_TYPE_ENUM = {bike: 0, shoe: 1}.freeze
  enum :gear_type, GEAR_TYPE_ENUM

  scope :bikes, -> { where(gear_type: :bike) }
  scope :shoes, -> { where(gear_type: :shoe) }
  scope :enriched, -> { where("strava_data->>'resource_state' = '3'") }
  scope :un_enriched, -> { where("strava_data IS NULL OR strava_data->>'resource_state' != '3'") }
  scope :with_item, -> { where.not(item_id: nil) }

  def self.update_from_strava(strava_integration, gear_data)
    strava_gear = strava_integration.strava_gears.find_or_initialize_by(strava_gear_id: gear_data["id"])

    calculated_gear_type = gear_data["gear_type"] || strava_gear.gear_type
    calculated_gear_type ||= gear_data.key?("frame_type") ? :bike : :shoe
    attrs = {strava_gear_name: gear_data["name"], gear_type: calculated_gear_type, strava_data: gear_data}
    if gear_data["resource_state"] == 3
      attrs[:last_updated_from_strava_at] = Time.current
    end
    strava_gear.update(attrs)
    strava_gear
  end

  def strava_gear_display_name
    strava_gear_name.presence || strava_gear_id
  end

  def strava_distance_km
    return nil if strava_data.blank?
    distance = strava_data["distance"]
    return nil if distance.blank?
    (distance.to_f / 1000).round(0)
  end

  def total_distance_miles
    return nil if total_distance_kilometers.blank?
    (total_distance_kilometers * 0.621371).round
  end

  def enriched?
    strava_data&.dig("resource_state") == 3
  end

  def primary?
    strava_data&.dig("primary") == true
  end

  def update_total_distance!
    total_meters = strava_integration.strava_activities.where(gear_id: strava_gear_id).sum(:distance_meters)
    update(total_distance_kilometers: (total_meters / 1000.0).round)
  end
end
