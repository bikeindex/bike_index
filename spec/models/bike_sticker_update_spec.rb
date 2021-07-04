require "rails_helper"

RSpec.describe BikeStickerUpdate, type: :model do
  describe "factory" do
    let(:bike_sticker_update) { FactoryBot.create(:bike_sticker_update) }
    it "is valid" do
      expect(bike_sticker_update.id).to be_present
      expect(bike_sticker_update.bike_sticker.organization_id).to be_blank
      expect(bike_sticker_update.bike_sticker.user_editable?).to be_truthy
    end
  end

  describe "user assocaition" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed) }
    let(:user) { bike_sticker.user }
    let!(:bike_sticker_update) { FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker) }
    it "associates" do
      user.reload
      expect(user.bike_sticker_updates.count).to eq 2
      expect(user.updated_bike_stickers.pluck(:id)).to eq([bike_sticker.id])
    end
  end
end
