require "rails_helper"

RSpec.describe Integrations::Bikebook::Data do
  before { sync_bikebook_models }

  describe "get_model" do
    let(:options) { {manufacturer: "Specialized", frame_model: "Haul ST", year: 2025} }
    let(:result) { described_class.get_model(options) }

    it "returns the model's bike and component params" do
      expect(result[:bike]).to match(cycle_type: "cargo", paint_description: nil, description: /\AWhatever you’re into/,
        rear_wheel_bsd: 406, stock_photo_url: "https://bikebook.bikeindex.org/specialized/2025/haul_st.png")
      expect(result[:components].count).to eq 32
      expect(result[:components]).to include({component_type: "Grips/Tape", description: "Globe closed end slip on type, 155mm",
                                              manufacturer: "Globe", front: false, rear: false}.as_json)
      expect(result[:components]).to include({component_type: "Brake", manufacturer: "Tektro", front: true, rear: true,
                                              description: "Tektro HD-T535, 4 piston caliper, hydraulic disc, 203mm rotor"}.as_json)
    end

    context "with a 1.x vocabulary, whose names are keyed by underscored slugs" do
      before do
        vocabulary = JSON.parse(BikebookCatalogHelpers::FIXTURES.join("vocabulary.json").read)
        vocabulary["names"]["components.type"].transform_keys! { it.tr("-", "_") }
        WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}vocabulary.json").to_return(body: vocabulary.to_json)
      end

      it "names each component's type" do
        expect(result[:components].pluck("component_type")).to include("Grips/Tape", "Bell/Noisemaker")
      end
    end

    context "with a year after the model's first" do
      let(:options) { {manufacturer: "Specialized", frame_model: "haul-st", year: "2026"} }

      it "returns the model" do
        expect(result[:bike][:cycle_type]).to eq "cargo"
      end
    end

    context "in its market variant's market" do
      let(:options) { {manufacturer: "Specialized", frame_model: "Haul ST", year: 2025, market: "CA"} }

      it "returns the variant" do
        expect(result[:bike][:stock_photo_url]).to eq "https://bikebook.bikeindex.org/specialized/2025/haul_st_ca.webp"
      end
    end

    context "with a year before the model's first" do
      let(:options) { {manufacturer: "Specialized", frame_model: "Haul ST", year: 2024} }

      it { expect(result).to be_nil }
    end

    context "with a bike" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Aventon") }
      let(:options) { FactoryBot.create(:bike, manufacturer:, frame_model: "Level 2", year: 2023) }

      it "returns the model" do
        expect(result[:bike][:cycle_type]).to eq "bike"
        expect(result[:components]).to be_present
      end
    end

    context "with a manufacturer the catalog lacks" do
      let(:options) { {manufacturer: "Some crazy manufacturer we have nothing on", frame_model: "Haul ST", year: 2025} }

      it { expect(result).to be_nil }
    end

    context "with the catalog unreachable" do
      before { stub_bikebook_catalog(status: 500) }

      it { expect(result).to be_nil }
    end
  end
end
