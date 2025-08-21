# == Schema Information
#
# Table name: bike_versions
#
#  id                        :bigint           not null, primary key
#  belt_drive                :boolean
#  cached_data               :text
#  coaster_brake             :boolean
#  cycle_type                :integer
#  deleted_at                :datetime
#  description               :text
#  end_at                    :datetime
#  extra_registration_number :string
#  frame_material            :integer
#  frame_model               :text
#  frame_size                :string
#  frame_size_number         :float
#  frame_size_unit           :string
#  front_tire_narrow         :boolean
#  handlebar_type            :integer
#  listing_order             :integer
#  manufacturer_other        :string
#  mnfg_name                 :string
#  name                      :string
#  number_of_seats           :integer
#  propulsion_type           :integer
#  rear_tire_narrow          :boolean
#  start_at                  :datetime
#  status                    :integer          default("status_with_owner")
#  thumb_path                :text
#  video_embed               :text
#  visibility                :integer          default("visible_not_related")
#  year                      :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  bike_id                   :bigint
#  front_gear_type_id        :bigint
#  front_wheel_size_id       :bigint
#  manufacturer_id           :bigint
#  owner_id                  :bigint
#  paint_id                  :bigint
#  primary_activity_id       :bigint
#  primary_frame_color_id    :bigint
#  rear_gear_type_id         :bigint
#  rear_wheel_size_id        :bigint
#  secondary_frame_color_id  :bigint
#  tertiary_frame_color_id   :bigint
#
# Indexes
#
#  index_bike_versions_on_bike_id                   (bike_id)
#  index_bike_versions_on_front_gear_type_id        (front_gear_type_id)
#  index_bike_versions_on_front_wheel_size_id       (front_wheel_size_id)
#  index_bike_versions_on_manufacturer_id           (manufacturer_id)
#  index_bike_versions_on_owner_id                  (owner_id)
#  index_bike_versions_on_paint_id                  (paint_id)
#  index_bike_versions_on_primary_activity_id       (primary_activity_id)
#  index_bike_versions_on_primary_frame_color_id    (primary_frame_color_id)
#  index_bike_versions_on_rear_gear_type_id         (rear_gear_type_id)
#  index_bike_versions_on_rear_wheel_size_id        (rear_wheel_size_id)
#  index_bike_versions_on_secondary_frame_color_id  (secondary_frame_color_id)
#  index_bike_versions_on_tertiary_frame_color_id   (tertiary_frame_color_id)
#
FactoryBot.define do
  factory :bike_version do
    bike { FactoryBot.create(:bike, :with_ownership_claimed) }
    sequence(:name) { |n| "Version #{n}" }
    manufacturer { bike.manufacturer }
    primary_frame_color { bike.primary_frame_color }
    owner { bike.owner }
    cycle_type { bike.cycle_type }
    propulsion_type { bike.propulsion_type }
  end
end
