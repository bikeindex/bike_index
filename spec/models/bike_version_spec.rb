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
require "rails_helper"

RSpec.describe BikeVersion, type: :model do
  it_behaves_like "bike_attributable"

  describe "factory" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    it "is valid" do
      expect(bike_version).to be_valid
      expect(bike_version.bike).to be_present
      expect(bike_version.owner).to eq bike_version.bike.owner
    end
  end

  describe "authorized? and visible_by?" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    let(:owner) { bike_version.owner }
    let(:user) { FactoryBot.create(:user) }
    let(:superuser) { FactoryBot.create(:superuser) }
    it "is false for non-owner" do
      expect(bike_version.authorized?(nil)).to be_falsey
      expect(bike_version.authorized?(user)).to be_falsey
      expect(bike_version.authorized?(owner)).to be_truthy
      expect(bike_version.authorized?(owner, no_superuser_override: true)).to be_truthy
      expect(bike_version.authorized?(superuser)).to be_truthy
      expect(bike_version.authorized?(superuser, no_superuser_override: true)).to be_falsey
      # visible
      expect(bike_version.visible_by?).to be_truthy
      expect(bike_version.visible_by?(user)).to be_truthy
      expect(bike_version.visible_by?(owner)).to be_truthy
      expect(bike_version.visible_by?(superuser)).to be_truthy
      # And off of user
      expect(user.authorized?(bike_version)).to be_falsey
      expect(owner.authorized?(bike_version)).to be_truthy
      expect(owner.authorized?(bike_version, no_superuser_override: true)).to be_truthy
      expect(superuser.authorized?(bike_version)).to be_truthy
      expect(superuser.authorized?(bike_version, no_superuser_override: true)).to be_falsey
    end
    context "user_hidden" do
      let(:bike_version) { FactoryBot.create(:bike_version, visibility: "user_hidden") }
      it "is as expected" do
        expect(bike_version.authorized?(nil)).to be_falsey
        expect(bike_version.authorized?(user)).to be_falsey
        expect(bike_version.authorized?(owner)).to be_truthy
        expect(bike_version.authorized?(owner, no_superuser_override: true)).to be_truthy
        expect(bike_version.authorized?(superuser)).to be_truthy
        expect(bike_version.authorized?(superuser, no_superuser_override: true)).to be_falsey
        # visible
        expect(bike_version.visible_by?).to be_falsey
        expect(bike_version.visible_by?(user)).to be_falsey
        expect(bike_version.visible_by?(owner)).to be_truthy
        expect(bike_version.visible_by?(superuser)).to be_truthy
      end
    end
  end

  describe "cached_data" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    it "caches" do
      expect(bike_version.reload.cached_data).to be_present
    end
  end
end
