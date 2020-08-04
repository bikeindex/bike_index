require "rails_helper"

RSpec.describe BikeStickerUpdate, type: :model do
  describe "factory" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
    it "is valid" do
      expect(bike_sticker.id).to be_present
    end
  end
end
