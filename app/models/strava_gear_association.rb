class StravaGearAssociation < ApplicationRecord
  belongs_to :strava_integration
  belongs_to :item, polymorphic: true

  validates :strava_gear_id, presence: true
  validates :item_type, uniqueness: {scope: :item_id, message: "already has a Strava gear association"}

  def strava_gear_display_name
    strava_gear_name.presence || strava_gear_id
  end
end
