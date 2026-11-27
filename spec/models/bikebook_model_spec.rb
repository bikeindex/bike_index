# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikebookModel, type: :model do
  before { sync_bikebook_models }

  describe "frame_model" do
    it "is a picked catalog id's or citation key's model name, and typed text as it is" do
      expect(described_class.frame_model("m/specialized/2025/haul-st")).to eq "Haul ST"
      expect(described_class.frame_model("m/specialized/2025/haul-st@CA")).to eq "Haul ST"
      expect(described_class.frame_model("m/specialized/2020/not-synced")).to eq "m/specialized/2020/not-synced"
      expect(described_class.frame_model("Haul ST custom")).to eq "Haul ST custom"
    end
  end

  describe "data" do
    let(:bikebook_model) { BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st") }

    it "is the model's record, its market's variant laid over it" do
      expect(bikebook_model.data_all_markets.keys).to match_array(["m/specialized/2025/haul-st", "m/specialized/2025/haul-st@CA"])
      expect(bikebook_model.data["description"]).to include("60 miles")
      expect(bikebook_model.data(market: "MX")["description"]).to include("60 miles")
      expect(bikebook_model.data(market: "CA")["description"]).to include("up to 100 km")
    end

    context "with a model the catalog lacks" do
      let(:bikebook_model) { BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st").dup.tap { it.update!(catalog_id: "m/specialized/2025/gone") } }

      it "is nil" do
        expect(bikebook_model.data_all_markets).to be_nil
        expect(bikebook_model.data).to be_nil
      end
    end
  end
end
