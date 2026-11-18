require "rails_helper"

RSpec.describe Backfills::ShortNameJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let!(:road) { FactoryBot.create(:primary_activity_family, name: "Road Biking") }
    let!(:endurance) { FactoryBot.create(:primary_activity, name: "Endurance / Sportive", primary_activity_family: road) }
    let!(:mtb) { FactoryBot.create(:primary_activity_family, name: "MTB (Mountain Biking)") }
    let!(:cassette) { FactoryBot.create(:ctype, name: "Cog/Cassette/Freewheel") }
    let!(:stem) { FactoryBot.create(:ctype, name: "Stem") }

    it "sets the short names that differ from the derived ones" do
      expect(road.short_name).to eq "Road Biking"
      expect(endurance.reload.display_name).to eq "Road Biking: Endurance / Sportive"

      instance.perform
      instance.perform

      expect(road.reload.short_name).to eq "Road"
      expect(endurance.reload.short_name).to eq "Endurance"
      expect(endurance.display_name).to eq "Road: Endurance / Sportive"
      expect(mtb.reload.short_name).to eq "MTB"
      expect(mtb[:short_name]).to be_nil
      expect(cassette.reload.short_name).to eq "Cassette"
      expect(stem.reload.short_name).to eq "Stem"
      expect(stem[:short_name]).to be_nil
    end
  end
end
