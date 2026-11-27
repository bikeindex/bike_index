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

  describe "market_data" do
    let(:bikebook_model) { BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st") }

    it "is the model's record, its market's variant laid over it" do
      expect(bikebook_model.data.keys).to match_array(["m/specialized/2025/haul-st", "m/specialized/2025/haul-st@CA"])
      expect(bikebook_model.market_data["description"]).to include("60 miles")
      expect(bikebook_model.market_data(market: "MX")["description"]).to include("60 miles")
      expect(bikebook_model.market_data(market: "CA")["description"]).to include("up to 100 km")
    end

    context "with a model whose data hasn't synced" do
      let(:bikebook_model) do
        BikebookModel.create!(catalog_id: "m/specialized/2025/unsynced", manufacturer: Manufacturer.friendly_find("Specialized"),
          name: "Unsynced", model_slug: "unsynced", first_year: 2025)
      end

      it "is nil" do
        expect(bikebook_model.market_data).to be_nil
      end
    end
  end
end
