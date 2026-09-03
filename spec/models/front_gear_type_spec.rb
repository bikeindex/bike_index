require "rails_helper"

RSpec.describe FrontGearType, type: :model do
  describe "pinion" do
    let!(:pinion) { FactoryBot.create(:front_gear_type, name: "12 Speed Pinion Gearbox", count: 12, internal: true) }
    let!(:standard) { FactoryBot.create(:front_gear_type, name: "3", count: 3, standard: true) }

    it "matches only the pinion gearbox types" do
      expect(FrontGearType.pinion.pluck(:id)).to eq([pinion.id])
    end
  end
end
