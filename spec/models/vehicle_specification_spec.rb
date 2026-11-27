# frozen_string_literal: true

require "rails_helper"

RSpec.describe VehicleSpecification, type: :model do
  describe "bikebook_model" do
    let(:bikebook_model) do
      BikebookModel.create!(catalog_id: "m/specialized/2020/dropped", manufacturer: FactoryBot.create(:manufacturer),
        name: "Dropped", model_slug: "dropped", first_year: 2020)
    end
    let(:vehicle_specification) { VehicleSpecification.create!(bike_obj: FactoryBot.create(:bike), bikebook_model:) }

    it "is the model after the catalog drops it" do
      bikebook_model.destroy
      expect(vehicle_specification.reload.bikebook_model).to eq bikebook_model
    end
  end

  describe "bikebook_data" do
    before { sync_bikebook_models }

    let(:bike) { FactoryBot.create(:bike, year: 2025) }
    let(:bikebook_market) { "US" }
    let(:bikebook_model) { BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st") }
    let(:vehicle_specification) { VehicleSpecification.create!(bike_obj: bike, bikebook_model:, bikebook_market:) }

    it "is the model's data in its market, as bike and component attributes" do
      expect(vehicle_specification.bikebook_data["description"]).to include("60 miles")
      expect(vehicle_specification.bikebook_data_bike_attributes).to include(cycle_type: "cargo-rear", rear_wheel_bsd: 406)
      expect(vehicle_specification.bikebook_data_component_attributes).to include({component_type: "Grips/Tape", manufacturer: "Globe",
                                                                                     description: "Globe closed end slip on type, 155mm", front: false, rear: false})
    end

    context "in its market variant's market" do
      let(:bikebook_market) { "CA" }

      it "is the variant" do
        expect(vehicle_specification.bikebook_data_bike_attributes[:description]).to include("up to 100 km")
      end
    end

    context "without a model" do
      let(:bikebook_model) { nil }

      it "is nil" do
        expect(vehicle_specification.bikebook_data).to be_nil
        expect(vehicle_specification.bikebook_data_bike_attributes).to be_nil
        expect(vehicle_specification.bikebook_data_component_attributes).to be_nil
      end
    end
  end
end
