require "rails_helper"

RSpec.describe BikeStickerUpdate, type: :model do
  describe "factory" do
    let(:bike_sticker_update) { FactoryBot.create(:bike_sticker_update) }
    it "is valid" do
      expect(bike_sticker_update.id).to be_present
    end
  end
end
