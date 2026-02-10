# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaGear, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      strava_gear = FactoryBot.build(:strava_gear)
      expect(strava_gear).to be_valid
    end

    it "is valid without item" do
      strava_gear = FactoryBot.build(:strava_gear, item: nil)
      expect(strava_gear).to be_valid
    end

    it "requires strava_gear_id" do
      strava_gear = FactoryBot.build(:strava_gear, strava_gear_id: nil)
      expect(strava_gear).not_to be_valid
      expect(strava_gear.errors[:strava_gear_id]).to be_present
    end

    it "requires strava_integration" do
      strava_gear = FactoryBot.build(:strava_gear, strava_integration: nil)
      expect(strava_gear).not_to be_valid
    end

    it "enforces uniqueness of strava_gear_id scoped to strava_integration" do
      strava_integration = FactoryBot.create(:strava_integration)
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234")
      duplicate = FactoryBot.build(:strava_gear, strava_integration:, strava_gear_id: "b1234")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:strava_gear_id]).to be_present
    end

    it "enforces uniqueness per item" do
      bike = FactoryBot.create(:bike)
      FactoryBot.create(:strava_gear, :with_bike, item: bike)
      duplicate = FactoryBot.build(:strava_gear, :with_bike, item: bike)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:item_id]).to be_present
    end
  end

  describe "scopes" do
    it "bikes returns gear_type bike" do
      bike_gear = FactoryBot.create(:strava_gear, gear_type: "bike")
      shoe_gear = FactoryBot.create(:strava_gear, :shoe)
      expect(StravaGear.bikes).to include(bike_gear)
      expect(StravaGear.bikes).not_to include(shoe_gear)
    end

    it "shoes returns gear_type shoe" do
      bike_gear = FactoryBot.create(:strava_gear, gear_type: "bike")
      shoe_gear = FactoryBot.create(:strava_gear, :shoe)
      expect(StravaGear.shoes).to include(shoe_gear)
      expect(StravaGear.shoes).not_to include(bike_gear)
    end

    it "enriched returns gear with resource_state 3" do
      enriched_gear = FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 3, "name" => "Bike"})
      un_enriched_gear = FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 2, "name" => "Bike"})
      nil_gear = FactoryBot.create(:strava_gear, strava_data: nil)
      expect(StravaGear.enriched).to include(enriched_gear)
      expect(StravaGear.enriched).not_to include(un_enriched_gear, nil_gear)
    end

    it "un_enriched returns gear without resource_state 3" do
      enriched_gear = FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 3, "name" => "Bike"})
      un_enriched_gear = FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 2, "name" => "Bike"})
      nil_gear = FactoryBot.create(:strava_gear, strava_data: nil)
      expect(StravaGear.un_enriched).to include(un_enriched_gear, nil_gear)
      expect(StravaGear.un_enriched).not_to include(enriched_gear)
    end
  end

  describe "#strava_gear_display_name" do
    it "returns gear name when present" do
      strava_gear = FactoryBot.build(:strava_gear, strava_gear_name: "My Road Bike")
      expect(strava_gear.strava_gear_display_name).to eq("My Road Bike")
    end

    it "returns gear id when name is blank" do
      strava_gear = FactoryBot.build(:strava_gear, strava_gear_name: nil, strava_gear_id: "b12345")
      expect(strava_gear.strava_gear_display_name).to eq("b12345")
    end
  end

  describe "#strava_distance_km" do
    it "returns distance in km from strava_data" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: {"distance" => 50000.0})
      expect(strava_gear.strava_distance_km).to eq(50)
    end

    it "returns nil when strava_data is blank" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: nil)
      expect(strava_gear.strava_distance_km).to be_nil
    end
  end

  describe "#enriched?" do
    it "returns true when resource_state is 3" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: {"resource_state" => 3})
      expect(strava_gear.enriched?).to be true
    end

    it "returns false when resource_state is 2" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: {"resource_state" => 2})
      expect(strava_gear.enriched?).to be false
    end

    it "returns false when strava_data is nil" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: nil)
      expect(strava_gear.enriched?).to be false
    end
  end

  describe "#primary?" do
    it "returns true when strava_data primary is true" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: {"primary" => true})
      expect(strava_gear.primary?).to be true
    end

    it "returns false when strava_data primary is false" do
      strava_gear = FactoryBot.build(:strava_gear, strava_data: {"primary" => false})
      expect(strava_gear.primary?).to be false
    end
  end

  describe ".update_from_strava" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "updates attributes from gear detail response" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
        strava_data: {"resource_state" => 2})
      detail = {
        "id" => "b1234", "name" => "Updated Bike Name", "resource_state" => 3,
        "distance" => 75000.0, "frame_type" => 3, "primary" => true
      }
      strava_gear = StravaGear.update_from_strava(strava_integration, detail)
      expect(strava_gear.strava_gear_name).to eq("Updated Bike Name")
      expect(strava_gear.strava_data["resource_state"]).to eq(3)
      expect(strava_gear.enriched?).to be true
      expect(strava_gear.last_updated_from_strava_at).to be_present
      expect(strava_gear.gear_type).to eq("bike")
    end

    it "creates a new gear record when not found" do
      gear_data = {"id" => "b9999", "name" => "New Bike", "gear_type" => "bike",
                   "resource_state" => 2, "distance" => 10000.0}
      expect { StravaGear.update_from_strava(strava_integration, gear_data) }
        .to change(StravaGear, :count).by(1)
      strava_gear = strava_integration.strava_gears.find_by(strava_gear_id: "b9999")
      expect(strava_gear.strava_gear_name).to eq("New Bike")
    end

    it "sets gear_type to shoe when no frame_type and no gear_type" do
      detail = {"id" => "g1234", "name" => "Running Shoes", "resource_state" => 3, "distance" => 5000.0}
      strava_gear = StravaGear.update_from_strava(strava_integration, detail)
      expect(strava_gear.gear_type).to eq("shoe")
    end

    it "preserves existing gear_type" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234", gear_type: "bike")
      detail = {"id" => "b1234", "name" => "Bike", "resource_state" => 3, "distance" => 5000.0}
      strava_gear = StravaGear.update_from_strava(strava_integration, detail)
      expect(strava_gear.gear_type).to eq("bike")
    end

    it "does not set last_updated_from_strava_at for summary data" do
      gear_data = {"id" => "b1234", "name" => "Bike", "gear_type" => "bike",
                   "resource_state" => 2, "distance" => 5000.0}
      strava_gear = StravaGear.update_from_strava(strava_integration, gear_data)
      expect(strava_gear.last_updated_from_strava_at).to be_nil
    end
  end

  describe "#update_total_distance!" do
    it "sums distance_meters from matching activities" do
      strava_gear = FactoryBot.create(:strava_gear, strava_gear_id: "b1234")
      strava_integration = strava_gear.strava_integration
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b1234", distance_meters: 10000.0)
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b1234", distance_meters: 15000.0)
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b9999", distance_meters: 5000.0)

      strava_gear.update_total_distance!
      expect(strava_gear.total_distance_kilometers).to eq(25)
    end

    it "sets zero when no matching activities" do
      strava_gear = FactoryBot.create(:strava_gear, strava_gear_id: "b1234")
      strava_gear.update_total_distance!
      expect(strava_gear.total_distance_kilometers).to eq(0)
    end
  end

  describe "dependent nullify from bike" do
    it "nullifies item when bike is destroyed" do
      strava_gear = FactoryBot.create(:strava_gear, :with_bike)
      bike = strava_gear.item
      bike.destroy
      expect(strava_gear.reload.item).to be_nil
    end

    it "is destroyed when strava_integration is destroyed" do
      strava_gear = FactoryBot.create(:strava_gear)
      strava_integration = strava_gear.strava_integration
      expect {
        strava_integration.destroy
      }.to change(StravaGear, :count).by(-1)
    end
  end
end
