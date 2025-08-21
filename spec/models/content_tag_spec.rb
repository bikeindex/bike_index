# == Schema Information
#
# Table name: content_tags
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  priority    :integer
#  slug        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "rails_helper"

RSpec.describe ContentTag, type: :model do
  it_behaves_like "friendly_slug_findable"

  describe "matching_ids" do
    let!(:content_tag1) { FactoryBot.create(:content_tag, name: "Bike Theft") }
    let!(:content_tag2) { FactoryBot.create(:content_tag, name: "Bike Recovery") }
    it "returns the matching ids" do
      expect(ContentTag.matching_ids(" ")).to eq([])
      expect(ContentTag.matching_ids([])).to eq([])
      expect(ContentTag.matching_ids("Bike Theft")).to eq([content_tag1.id])
      expect(ContentTag.matching_ids(["Bike THEFT", "Bike-theft"])).to eq([content_tag1.id])
      expect(ContentTag.matching_ids("Bike THEFT, OTher thing")).to eq([content_tag1.id])
      expect(ContentTag.matching_ids("Bike THEFT, OTher, thing\n Bike Recovery")).to match_array([content_tag1.id, content_tag2.id])
      expect(ContentTag.matching_ids(["Bike THEFT", "OTher thing", "\nBike Recovery"])).to match_array([content_tag1.id, content_tag2.id])
    end
  end
end
