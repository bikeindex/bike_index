# == Schema Information
#
# Table name: strava_gear_associations
# Database name: primary
#
#  id                    :bigint           not null, primary key
#  item_type             :string           not null
#  strava_gear_name      :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  item_id               :bigint           not null
#  strava_gear_id        :string           not null
#  strava_integration_id :bigint           not null
#
# Indexes
#
#  idx_on_strava_integration_id_strava_gear_id_37c80b184d   (strava_integration_id,strava_gear_id)
#  index_strava_gear_associations_on_item                   (item_type,item_id)
#  index_strava_gear_associations_on_item_type_and_item_id  (item_type,item_id) UNIQUE
#  index_strava_gear_associations_on_strava_integration_id  (strava_integration_id)
#
# Foreign Keys
#
#  fk_rails_...  (strava_integration_id => strava_integrations.id)
#
class StravaGearAssociation < ApplicationRecord
  belongs_to :strava_integration
  belongs_to :item, polymorphic: true

  validates :strava_gear_id, presence: true
  validates :item_type, uniqueness: {scope: :item_id, message: "already has a Strava gear association"}

  def strava_gear_display_name
    strava_gear_name.presence || strava_gear_id
  end
end
