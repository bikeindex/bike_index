# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaGear, type: :model do
  describe "validations" do
    context "with valid attributes" do
      it "is valid" do
        expect(FactoryBot.build(:strava_gear)).to be_valid
      end
    end

    context "without item" do
      it "is valid" do
        expect(FactoryBot.build(:strava_gear, item: nil)).to be_valid
      end
    end

    context "without strava_gear_id" do
      it "is invalid" do
        strava_gear = FactoryBot.build(:strava_gear, strava_gear_id: nil)
        expect(strava_gear).not_to be_valid
        expect(strava_gear.errors[:strava_gear_id]).to be_present
      end
    end

    context "without strava_integration" do
      it "is invalid" do
        expect(FactoryBot.build(:strava_gear, strava_integration: nil)).not_to be_valid
      end
    end

    context "with duplicate strava_gear_id for same strava_integration" do
      let(:strava_integration) { FactoryBot.create(:strava_integration) }

      it "is invalid" do
        FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234")
        duplicate = FactoryBot.build(:strava_gear, strava_integration:, strava_gear_id: "b1234")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:strava_gear_id]).to be_present
      end
    end

    context "with duplicate item" do
      let(:bike) { FactoryBot.create(:bike) }

      it "is invalid" do
        FactoryBot.create(:strava_gear, :with_bike, item: bike)
        duplicate = FactoryBot.build(:strava_gear, :with_bike, item: bike)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:item_id]).to be_present
      end
    end
  end

  describe "scopes" do
    let!(:bike_gear) { FactoryBot.create(:strava_gear, gear_type: "bike") }
    let!(:shoe_gear) { FactoryBot.create(:strava_gear, :shoe) }

    describe ".bikes" do
      it "returns bike gear" do
        expect(StravaGear.bikes).to include(bike_gear)
        expect(StravaGear.bikes).not_to include(shoe_gear)
      end
    end

    describe ".shoes" do
      it "returns shoe gear" do
        expect(StravaGear.shoes).to include(shoe_gear)
        expect(StravaGear.shoes).not_to include(bike_gear)
      end
    end

    describe ".enriched" do
      let!(:enriched_gear) { FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 3, "name" => "Bike"}) }
      let!(:un_enriched_gear) { FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 2, "name" => "Bike"}) }
      let!(:nil_gear) { FactoryBot.create(:strava_gear, strava_data: nil) }

      it "returns gear with resource_state 3" do
        expect(StravaGear.enriched).to include(enriched_gear)
        expect(StravaGear.enriched).not_to include(un_enriched_gear, nil_gear)
      end
    end

    describe ".un_enriched" do
      let!(:enriched_gear) { FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 3, "name" => "Bike"}) }
      let!(:un_enriched_gear) { FactoryBot.create(:strava_gear, strava_data: {"resource_state" => 2, "name" => "Bike"}) }
      let!(:nil_gear) { FactoryBot.create(:strava_gear, strava_data: nil) }

      it "returns gear without resource_state 3" do
        expect(StravaGear.un_enriched).to include(un_enriched_gear, nil_gear)
        expect(StravaGear.un_enriched).not_to include(enriched_gear)
      end
    end
  end

  describe "#strava_gear_display_name" do
    let(:strava_gear) { FactoryBot.build(:strava_gear, name:, strava_gear_id: "b12345") }

    context "with name present" do
      let(:name) { "My Road Bike" }

      it "returns gear name" do
        expect(strava_gear.strava_gear_display_name).to eq("My Road Bike")
      end
    end

    context "with name blank" do
      let(:name) { nil }

      it "returns gear id" do
        expect(strava_gear.strava_gear_display_name).to eq("b12345")
      end
    end
  end

  describe "#strava_distance_km" do
    let(:strava_gear) { FactoryBot.build(:strava_gear, strava_data:) }

    context "with distance in strava_data" do
      let(:strava_data) { {"distance" => 50000.0} }

      it "returns distance in km" do
        expect(strava_gear.strava_distance_km).to eq(50)
      end
    end

    context "with nil strava_data" do
      let(:strava_data) { nil }

      it "returns nil" do
        expect(strava_gear.strava_distance_km).to be_nil
      end
    end
  end

  describe "#total_distance_miles" do
    let(:strava_gear) { FactoryBot.build(:strava_gear, total_distance_kilometers:) }

    context "with total_distance_kilometers present" do
      let(:total_distance_kilometers) { 100 }

      it "converts to miles" do
        expect(strava_gear.total_distance_miles).to eq(62)
      end
    end

    context "with nil total_distance_kilometers" do
      let(:total_distance_kilometers) { nil }

      it "returns nil" do
        expect(strava_gear.total_distance_miles).to be_nil
      end
    end
  end

  describe "#enriched?" do
    let(:strava_gear) { FactoryBot.build(:strava_gear, strava_data:) }

    context "with resource_state 3" do
      let(:strava_data) { {"resource_state" => 3} }

      it "returns true" do
        expect(strava_gear.enriched?).to be true
      end
    end

    context "with resource_state 2" do
      let(:strava_data) { {"resource_state" => 2} }

      it "returns false" do
        expect(strava_gear.enriched?).to be false
      end
    end

    context "with nil strava_data" do
      let(:strava_data) { nil }

      it "returns false" do
        expect(strava_gear.enriched?).to be false
      end
    end
  end

  describe "#primary?" do
    let(:strava_gear) { FactoryBot.build(:strava_gear, strava_data:) }

    context "with primary true" do
      let(:strava_data) { {"primary" => true} }

      it "returns true" do
        expect(strava_gear.primary?).to be true
      end
    end

    context "with primary false" do
      let(:strava_data) { {"primary" => false} }

      it "returns false" do
        expect(strava_gear.primary?).to be false
      end
    end
  end

  describe "#proxy_serialized" do
    let(:strava_gear) { FactoryBot.build(:strava_gear, name: "Cool bike", strava_data:, total_distance_kilometers:) }

    context "with strava_data and total_distance_kilometers" do
      let(:strava_data) { {"resource_state" => 3, "distance" => 50000.0} }
      let(:total_distance_kilometers) { 100 }
      let(:target_response) { {name: "Cool bike", resource_state: 3, distance: 100000.0} }

      it "returns strava_data with distance from total_distance_kilometers" do
        expect(strava_gear.proxy_serialized).to eq(target_response.as_json)
      end
    end

    context "with lower total_distance_kilometers" do
      let(:strava_data) { {name: "Cool bike", distance: 999999}.as_json }
      let(:total_distance_kilometers) { 99 }
      let(:target_response) { {"name" => "Cool bike", "distance" => 999999} }

      it "returns distance from strava_data" do
        expect(strava_gear.proxy_serialized).to eq(target_response)
      end

      context "with nil total_distance_kilometers" do
        let(:total_distance_kilometers) { nil }

        it "returns distance from strava_data" do
          expect(strava_gear.proxy_serialized).to eq(target_response)
        end
      end
    end
  end

  describe ".update_from_strava" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    context "with existing gear and detail response" do
      let(:detail) do
        {"id" => "b1234", "name" => "Updated Bike Name", "resource_state" => 3,
         "distance" => 75000.0, "frame_type" => 3, "primary" => true}
      end
      let(:target_strava_data) do
        {distance: 75000.0, frame_type: 3, id: "b1234", primary: true, resource_state: 3}
      end

      it "updates attributes from gear detail response" do
        FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
          strava_data: {"resource_state" => 2})
        strava_gear = StravaGear.update_from_strava(strava_integration, detail)
        expect(strava_gear).to be_valid
        expect(strava_gear.reload.name).to eq("Updated Bike Name")
        expect(strava_gear.strava_data).to eq target_strava_data.as_json
        expect(strava_gear.enriched?).to be true
        expect(strava_gear.last_updated_from_strava_at).to be_present
        expect(strava_gear.gear_type).to eq("bike")
      end
    end

    context "when gear record not found" do
      let(:gear_data) { {"id" => "b9999", "name" => "New Bike", "gear_type" => "bike", "resource_state" => 2, "distance" => 10000.0} }

      it "creates a new gear record" do
        expect { StravaGear.update_from_strava(strava_integration, gear_data) }
          .to change(StravaGear, :count).by(1)
        strava_gear = strava_integration.strava_gears.find_by(strava_gear_id: "b9999")
        expect(strava_gear.name).to eq("New Bike")
      end
    end

    context "with no frame_type and no gear_type" do
      let(:detail) { {"id" => "g1234", "name" => "Running Shoes", "resource_state" => 3, "distance" => 5000.0} }

      it "sets gear_type to shoe" do
        strava_gear = StravaGear.update_from_strava(strava_integration, detail)
        expect(strava_gear.gear_type).to eq("shoe")
      end
    end

    context "with existing gear_type" do
      let(:detail) { {"id" => "b1234", "name" => "Bike", "resource_state" => 3, "distance" => 5000.0} }

      it "preserves existing gear_type" do
        FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234", gear_type: "bike")
        strava_gear = StravaGear.update_from_strava(strava_integration, detail)
        expect(strava_gear.gear_type).to eq("bike")
      end
    end

    context "with summary data (resource_state 2)" do
      let(:gear_data) { {"id" => "b1234", "name" => "Bike", "gear_type" => "bike", "resource_state" => 2, "distance" => 5000.0} }

      it "does not set last_updated_from_strava_at" do
        strava_gear = StravaGear.update_from_strava(strava_integration, gear_data)
        expect(strava_gear.last_updated_from_strava_at).to be_nil
      end
    end
  end

  describe "#update_total_distance!" do
    let(:strava_gear) { FactoryBot.create(:strava_gear, strava_gear_id: "b1234") }
    let(:strava_integration) { strava_gear.strava_integration }

    context "with matching activities" do
      it "sums distance_meters from matching activities" do
        FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b1234", distance_meters: 10000.0)
        FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b1234", distance_meters: 15000.0)
        FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b9999", distance_meters: 5000.0)
        strava_gear.update_total_distance!
        expect(strava_gear.total_distance_kilometers).to eq(25)
      end
    end

    context "without matching activities" do
      it "sets zero" do
        strava_gear.update_total_distance!
        expect(strava_gear.total_distance_kilometers).to eq(0)
      end
    end
  end

  describe "dependent nullify from bike" do
    context "when bike is destroyed" do
      it "nullifies item" do
        strava_gear = FactoryBot.create(:strava_gear, :with_bike)
        bike = strava_gear.item
        bike.destroy
        expect(strava_gear.reload.item).to be_nil
      end
    end

    context "when strava_integration is destroyed" do
      it "destroys strava_gear" do
        strava_gear = FactoryBot.create(:strava_gear)
        strava_integration = strava_gear.strava_integration
        expect {
          strava_integration.destroy
        }.to change(StravaGear, :count).by(-1)
      end
    end
  end
end
