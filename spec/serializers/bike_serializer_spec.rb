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
require "rails_helper"

RSpec.describe BikeSerializer, type: :lib do
  let(:subject) { described_class }
  let(:bike) { FactoryBot.create(:bike, frame_size: "42") }
  let(:serializer) { subject.new(bike) }

  describe "standard validations" do
    let!(:component) { FactoryBot.create(:component, bike: bike) }
    let!(:public_image) { FactoryBot.create(:public_image, imageable_type: "Bike", imageable_id: bike.id) }
    it "is as expected" do
      expect(serializer.manufacturer_name).to eq(bike.mnfg_name)
      expect(serializer.manufacturer_id).to eq(bike.manufacturer_id)
      expect(serializer.stolen).to eq(bike.status_stolen?)
      expect(serializer.type_of_cycle).to eq("Bike")
      expect(serializer.name).to eq(bike.name)
      expect(serializer.year).to eq(bike.year)
      expect(serializer.frame_model).to eq(bike.frame_model)
      expect(serializer.description).to eq(bike.description)
      expect(serializer.rear_tire_narrow).to eq(bike.rear_tire_narrow)
      expect(serializer.front_tire_narrow).to eq(bike.front_tire_narrow)
      expect(serializer.rear_wheel_size).to eq(bike.rear_wheel_size)
      expect(serializer.serial).to eq(bike.serial_number.upcase)
      expect(serializer.front_wheel_size).to eq(bike.front_wheel_size)
      expect(serializer.handlebar_type).to eq(bike.handlebar_type)
      expect(serializer.frame_material).to eq(bike.frame_material)
      expect(serializer.front_gear_type).to eq(bike.front_gear_type)
      expect(serializer.rear_gear_type).to eq(bike.rear_gear_type)
      expect(serializer.stolen_record).to eq(bike.current_stolen_record)
      expect(serializer.frame_size).to eq("42cm")
      # expect(serializer.photo).to == bike.reload.public_images.first.image_url(:large)
      # expect(serializer.thumb).to == bike.reload.public_images.first.image_url(:small)
    end
  end
  describe "caching" do
    include_context :caching_basic
    it "is cached" do
      expect(serializer.perform_caching).to be_truthy
      expect(serializer.as_json.is_a?(Hash)).to be_truthy
      expect(serializer.cache_key).to match bike.cache_key_with_version
    end
  end
end
