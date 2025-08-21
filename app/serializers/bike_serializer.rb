# == Schema Information
#
# Table name: bikes
#
#  id                          :integer          not null, primary key
#  address_set_manually        :boolean          default(FALSE)
#  all_description             :text
#  belt_drive                  :boolean          default(FALSE), not null
#  cached_data                 :text
#  city                        :string
#  coaster_brake               :boolean          default(FALSE), not null
#  credibility_score           :integer
#  cycle_type                  :integer          default("bike")
#  deleted_at                  :datetime
#  description                 :text
#  example                     :boolean          default(FALSE), not null
#  extra_registration_number   :string(255)
#  frame_material              :integer
#  frame_model                 :text
#  frame_size                  :string(255)
#  frame_size_number           :float
#  frame_size_unit             :string(255)
#  front_tire_narrow           :boolean
#  handlebar_type              :integer
#  is_for_sale                 :boolean          default(FALSE), not null
#  is_phone                    :boolean          default(FALSE)
#  latitude                    :float
#  likely_spam                 :boolean          default(FALSE)
#  listing_order               :integer
#  longitude                   :float
#  made_without_serial         :boolean          default(FALSE), not null
#  manufacturer_other          :string(255)
#  mnfg_name                   :string(255)
#  name                        :string(255)
#  neighborhood                :string
#  number_of_seats             :integer
#  occurred_at                 :datetime
#  owner_email                 :text
#  pdf                         :string(255)
#  propulsion_type             :integer          default("foot-pedal")
#  rear_tire_narrow            :boolean          default(TRUE)
#  serial_normalized           :string(255)
#  serial_normalized_no_space  :string
#  serial_number               :string(255)      not null
#  serial_segments_migrated_at :datetime
#  status                      :integer          default("status_with_owner")
#  stock_photo_url             :string(255)
#  street                      :string
#  thumb_path                  :text
#  updated_by_user_at          :datetime
#  user_hidden                 :boolean          default(FALSE), not null
#  video_embed                 :text
#  year                        :integer
#  zipcode                     :string(255)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  country_id                  :integer
#  creation_organization_id    :integer
#  creator_id                  :integer
#  current_impound_record_id   :bigint
#  current_ownership_id        :bigint
#  current_stolen_record_id    :integer
#  front_gear_type_id          :integer
#  front_wheel_size_id         :integer
#  manufacturer_id             :integer
#  model_audit_id              :bigint
#  paint_id                    :integer
#  primary_activity_id         :bigint
#  primary_frame_color_id      :integer
#  rear_gear_type_id           :integer
#  rear_wheel_size_id          :integer
#  secondary_frame_color_id    :integer
#  state_id                    :bigint
#  tertiary_frame_color_id     :integer
#  updator_id                  :integer
#
# Indexes
#
#  index_bikes_on_current_impound_record_id  (current_impound_record_id)
#  index_bikes_on_current_ownership_id       (current_ownership_id)
#  index_bikes_on_current_stolen_record_id   (current_stolen_record_id)
#  index_bikes_on_deleted_at                 (deleted_at)
#  index_bikes_on_example                    (example)
#  index_bikes_on_latitude_and_longitude     (latitude,longitude)
#  index_bikes_on_listing_order              (listing_order)
#  index_bikes_on_manufacturer_id            (manufacturer_id)
#  index_bikes_on_model_audit_id             (model_audit_id)
#  index_bikes_on_organization_id            (creation_organization_id)
#  index_bikes_on_paint_id                   (paint_id)
#  index_bikes_on_primary_activity_id        (primary_activity_id)
#  index_bikes_on_primary_frame_color_id     (primary_frame_color_id)
#  index_bikes_on_secondary_frame_color_id   (secondary_frame_color_id)
#  index_bikes_on_state_id                   (state_id)
#  index_bikes_on_status                     (status)
#  index_bikes_on_tertiary_frame_color_id    (tertiary_frame_color_id)
#  index_bikes_on_user_hidden                (user_hidden)
#
class BikeSerializer < ApplicationSerializer
  attributes :id,
    :serial,
    :registration_created_at,
    :registration_updated_at,
    :url,
    :api_url,
    :manufacturer_name,
    :manufacturer_id,
    :frame_colors,
    :paint_description,
    :stolen,
    :name,
    :year,
    :frame_model,
    :frame_size,
    :description,
    :rear_tire_narrow,
    :front_tire_narrow,
    :photo,
    :thumb,
    :title,
    :type_of_cycle,
    :frame_material,
    :handlebar_type

  has_one :rear_wheel_size,
    :front_wheel_size,
    :front_gear_type,
    :rear_gear_type,
    :stolen_record

  def serial
    object.serial_display
  end

  def type_of_cycle
    object.cycle_type_name
  end

  def manufacturer_name
    object.mnfg_name
  end

  def url
    object.html_url
  end

  def api_url
    "#{ENV["BASE_URL"]}/api/v1/bikes/#{object.id}"
  end

  def title
    object.title_string + "(#{object.frame_colors.to_sentence.downcase})"
  end

  def registration_created_at
    object.created_at
  end

  def registration_updated_at
    object.updated_at
  end

  def stolen
    object.status_stolen?
  end

  def stolen_record
    object.current_stolen_record if object.current_stolen_record.present?
  end

  def photo
    object.image_url(:large)
  end

  def thumb
    BikeServices::Displayer.thumb_image_url(object)
  end

  def frame_material
    object.frame_material_name
  end

  def handlebar_type
    object.handlebar_type_name
  end
end
