require "rails_helper"

RSpec.describe StravaGearAssociation, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      strava_gear_association = FactoryBot.build(:strava_gear_association)
      expect(strava_gear_association).to be_valid
    end

    it "requires strava_gear_id" do
      strava_gear_association = FactoryBot.build(:strava_gear_association, strava_gear_id: nil)
      expect(strava_gear_association).not_to be_valid
      expect(strava_gear_association.errors[:strava_gear_id]).to be_present
    end

    it "requires strava_integration" do
      strava_gear_association = FactoryBot.build(:strava_gear_association, strava_integration: nil)
      expect(strava_gear_association).not_to be_valid
    end

    it "requires item" do
      strava_gear_association = FactoryBot.build(:strava_gear_association, item: nil)
      expect(strava_gear_association).not_to be_valid
    end

    it "enforces uniqueness per item" do
      bike = FactoryBot.create(:bike)
      FactoryBot.create(:strava_gear_association, item: bike)
      duplicate = FactoryBot.build(:strava_gear_association, item: bike)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:item_type]).to be_present
    end
  end

  describe "associations" do
    it "belongs to strava_integration" do
      association = described_class.reflect_on_association(:strava_integration)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to item (polymorphic)" do
      association = described_class.reflect_on_association(:item)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:polymorphic]).to eq(true)
    end
  end

  describe "#strava_gear_display_name" do
    it "returns gear name when present" do
      strava_gear_association = FactoryBot.build(:strava_gear_association, strava_gear_name: "My Road Bike")
      expect(strava_gear_association.strava_gear_display_name).to eq("My Road Bike")
    end

    it "returns gear id when name is blank" do
      strava_gear_association = FactoryBot.build(:strava_gear_association, strava_gear_name: nil, strava_gear_id: "b12345")
      expect(strava_gear_association.strava_gear_display_name).to eq("b12345")
    end
  end

  describe "#update_total_distance!" do
    it "sums distance_meters from matching activities" do
      ga = FactoryBot.create(:strava_gear_association, strava_gear_id: "b1234")
      si = ga.strava_integration
      FactoryBot.create(:strava_activity, strava_integration: si, gear_id: "b1234", distance_meters: 10000.0)
      FactoryBot.create(:strava_activity, strava_integration: si, gear_id: "b1234", distance_meters: 15000.0)
      FactoryBot.create(:strava_activity, strava_integration: si, gear_id: "b9999", distance_meters: 5000.0)

      ga.update_total_distance!
      expect(ga.total_distance_kilometers).to eq(25)
    end

    it "sets zero when no matching activities" do
      ga = FactoryBot.create(:strava_gear_association, strava_gear_id: "b1234")
      ga.update_total_distance!
      expect(ga.total_distance_kilometers).to eq(0)
    end
  end

  describe "dependent destroy" do
    it "is destroyed when bike is destroyed" do
      strava_gear_association = FactoryBot.create(:strava_gear_association)
      bike = strava_gear_association.item
      expect {
        bike.destroy
      }.to change(StravaGearAssociation, :count).by(-1)
    end

    it "is destroyed when strava_integration is destroyed" do
      strava_gear_association = FactoryBot.create(:strava_gear_association)
      strava_integration = strava_gear_association.strava_integration
      expect {
        strava_integration.destroy
      }.to change(StravaGearAssociation, :count).by(-1)
    end
  end
end
