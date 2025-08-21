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

  describe "user association" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed) }
    let(:user) { bike_sticker.user }
    let!(:bike_sticker_update) { FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker) }
    it "associates" do
      user.reload
      expect(user.bike_sticker_updates.count).to eq 2
      expect(user.updated_bike_stickers.pluck(:id)).to eq([bike_sticker.id])
    end
  end

  describe "safe_assign_creator_kind" do
    let(:bike_sticker) { BikeSticker.new }
    let(:ownership) { Ownership.new }
    let(:bike) { Bike.new(current_ownership: ownership) }
    let(:bike_sticker_update) { bike_sticker.bike_sticker_updates.new(bike: bike, safe_assign_creator_kind: creator_kind) }
    let(:creator_kind) { nil }
    it "does nothing with nil" do
      expect(bike_sticker_update.creator_kind).to be_blank
    end
    context "random" do
      let(:creator_kind) { "partypartyparty" }
      it "is nil" do
        expect(bike_sticker_update.creator_kind).to be_blank
      end
    end
    context "creator_export" do
      let(:creator_kind) { "creator_export" }
      it "assigns" do
        expect(bike_sticker_update.creator_kind).to eq "creator_export"
      end
    end
    context "creator_bike_creation" do
      let(:creator_kind) { "creator_bike_creation" }
      it "assigns" do
        expect(bike_sticker_update.creator_kind).to eq "creator_bike_creation"
        expect(bike_sticker_update.creator_kind_humanized).to eq "bike registration"
      end
      context "bike pos registration" do
        let(:ownership) { Ownership.new(pos_kind: "ascend_pos") }
        it "assigns creator_pos" do
          expect(bike_sticker_update.bike&.current_ownership&.pos?).to be_truthy
          expect(bike.current_ownership.pos?).to be_truthy
          expect(bike_sticker_update.creator_kind).to eq "creator_pos"
        end
      end
      context "creator_import" do
        let(:organization) { FactoryBot.create(:organization) }
        let!(:bulk_import) { FactoryBot.create(:bulk_import, organization: organization) }
        let(:ownership) { Ownership.new(bulk_import: bulk_import, organization: organization) }
        it "assigns creator_pos" do
          expect(bike_sticker_update.bike.current_ownership.bulk?).to be_truthy
          expect(bike_sticker_update.creator_kind).to eq "creator_import"
          expect(bike_sticker_update.organization_id).to eq organization.id
          expect(bike_sticker_update.bulk_import_id).to eq bulk_import.id
        end
      end
    end
  end
end
