require 'rails_helper'

RSpec.describe BikeVersion, type: :model do
  describe "factory" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    it "is valid" do
      expect(bike_version).to be_valid
      expect(bike_version.bike).to be_present
      expect(bike_version.owner).to eq bike_version.bike.owner
    end
  end
end
