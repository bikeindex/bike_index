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
end
