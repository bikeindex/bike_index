require "rails_helper"

RSpec.describe Integrations::Bikebook::Data do
  before { sync_bikebook_models }

  describe "get_model" do
    let(:manufacturer_id) { Manufacturer.friendly_find("Specialized").id }
    let(:options) { {manufacturer_id:, frame_model: "Haul ST", year: 2025} }
    let(:result) { described_class.get_model(described_class.vehicle_specification(options), year: options[:year]) }

    it "returns the model's bike and component params" do
      expect(result[:bike]).to match(cycle_type: "cargo-rear", paint_description: nil, description: /\AWhatever you’re into.* 60 miles/,
        rear_wheel_bsd: 406, stock_photo_url: "https://bikebook.bikeindex.org/specialized/2025/haul-st.png")
      expect(result[:components].count).to eq 32
      expect(result[:components]).to include({component_type: "Grips/Tape", description: "Globe closed end slip on type, 155mm",
                                              manufacturer: "Globe", front: false, rear: false}.as_json)
      expect(result[:components]).to include({component_type: "Brake", manufacturer: "Tektro", front: true, rear: true,
                                              description: "Tektro HD-T535, 4 piston caliper, hydraulic disc, 203mm rotor"}.as_json)
    end

    context "with a year after the model's first" do
      let(:options) { {manufacturer_id:, frame_model: "haul-st", year: "2026"} }

      it "returns the model" do
        expect(result[:bike][:cycle_type]).to eq "cargo-rear"
      end
    end

    context "in its market variant's market" do
      let(:options) { {manufacturer_id:, frame_model: "Haul ST", year: 2025, market: "CA"} }

      it "returns the variant" do
        expect(result[:bike][:description]).to include("up to 100 km")
      end
    end

    context "in a market without a variant" do
      let(:options) { {manufacturer_id:, frame_model: "Haul ST", year: 2025, market: "MX"} }

      it "returns the model" do
        expect(result[:bike][:description]).to include("60 miles")
      end
    end

    context "with a bike" do
      let(:options) { FactoryBot.create(:bike, manufacturer: Manufacturer.friendly_find("Aventon"), frame_model: "Level 2", year: 2023) }

      it "returns the model" do
        expect(result[:bike][:cycle_type]).to eq "bike"
        expect(result[:components]).to be_present
      end
    end

    context "with a manufacturer the catalog lacks" do
      let(:manufacturer_id) { FactoryBot.create(:manufacturer, name: "Some crazy manufacturer we have nothing on").id }

      it { expect(result).to be_nil }
    end

    context "with the catalog unreachable" do
      before { stub_bikebook_catalog(status: 500) }

      it { expect(result).to be_nil }
    end
  end

  describe "vehicle_specification" do
    let(:manufacturer_id) { Manufacturer.friendly_find("Specialized").id }
    let(:options) { {manufacturer_id:, frame_model: "Haul ST", year: 2025, market: "CA"} }
    let(:result) { described_class.vehicle_specification(options) }

    it "is the model matching the name and year, in the market" do
      expect(result).to have_attributes(bikebook_model: BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st"), bikebook_market: "CA",
        new_record?: true)
      expect(result.bikebook_id).to eq "m/specialized/2025/haul-st@CA"
    end

    context "with a picked bikebook_model" do
      let(:options) { {manufacturer_id:, frame_model: "Something else", year: 2025, bikebook_model: "m/specialized/2025/haul-st@CA"} }

      it "is the picked model, in its citation key's market" do
        expect(result.bikebook_id).to eq "m/specialized/2025/haul-st@CA"
      end

      context "without a year" do
        let(:options) { super().except(:year) }

        it { expect(result).to be_nil }
      end

      context "of another manufacturer" do
        let(:manufacturer_id) { Manufacturer.friendly_find("Aventon").id }

        it { expect(result).to be_nil }
      end

      context "not sold in the year" do
        let(:options) { super().merge(year: 2019) }

        it { expect(result).to be_nil }
      end
    end

    context "with a bike that has one" do
      let(:options) { FactoryBot.create(:bike, manufacturer: Manufacturer.friendly_find("Specialized"), frame_model: "Not it", year: 2025) }
      let!(:vehicle_specification) { VehicleSpecification.create!(bike_obj: options, bikebook_model: BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st"), bikebook_market: "CA") }

      it "is the bike's" do
        expect(result).to eq vehicle_specification
      end
    end
  end
end
