require "rails_helper"

RSpec.describe WheelSize, type: :model do
  describe "popularity" do
    it "returns the popularities word of the wheel size" do
      wheel_size = WheelSize.new(priority: 1)
      expect(wheel_size.popularity).to eq("Standard")
      wheel_size.priority = 4
      expect(wheel_size.popularity).to eq("Rare")
    end
  end

  describe "find_id_by_iso_bsd" do
    context "string iso_bsd" do
      it "returns the id" do
        wheel_size = FactoryBot.create(:wheel_size, iso_bsd: 622)
        expect(WheelSize.id_for_bsd("\n622 ")).to eq wheel_size.id
      end
    end
    context "unknown number" do
      it "returns nil" do
        expect(WheelSize.id_for_bsd("6220")).to be_nil
      end
    end
  end
end
