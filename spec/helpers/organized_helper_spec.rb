require "spec_helper"

describe OrganizedHelper do
  describe "organized bike display" do
    let(:bike) { FactoryGirl.create(:creation_organization_bike) }
    let(:target_text) do
      "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong></span>"
    end
    it "renders" do
      expect(organized_bike_text).to be_nil
      expect(organized_bike_text(bike)).to eq target_text
    end
  end
end
