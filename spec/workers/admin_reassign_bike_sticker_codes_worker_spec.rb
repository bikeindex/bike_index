require "rails_helper"

RSpec.describe AdminReassignBikeStickerCodesWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization2) { FactoryBot.create(:organization) }
    let!(:user) { FactoryBot.create(:admin) }
    let(:user2) { FactoryBot.create(:user) }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch, prefix: "A", code_number_length: nil, organization: organization) }
    let(:bike_sticker1) { FactoryBot.create(:bike_sticker, code: "A 1222") }
    it "creates" do
      expect(bike_sticker1.reload.bike_sticker_updates.count).to eq 0
      expect(bike_sticker_batch.bike_stickers.count).to eq 0
      bike_sticker_batch.create_codes(4, initial_code_integer: 1221)
      bike_stickers = bike_sticker_batch.reload.bike_stickers
      expect(bike_stickers.count).to eq 4
      expect(BikeStickerUpdate.where(bike_id: bike_stickers.pluck(:id)).count).to eq 0
      expect(BikeSticker.lookup("A1 22 2")&.id).to eq bike_sticker1.id
      bike_sticker2 = BikeSticker.lookup("A1 22 2", organization_id: organization.id)
      expect(bike_sticker2).to be_present
      # Claim one of the stickers - to test that a claimed sticker isn't broken in this process
      bike_sticker2.claim(user: user2, bike: bike) # ... lazily assigning to the same bike for now
      expect(bike_sticker2.user_id).to eq user2.id
      expect(bike_sticker2.organization_id).to eq organization.id
      expect(bike_sticker2.bike_id).to eq bike.id
      bike_sticker3 = BikeSticker.lookup("A1 22 3", organization_id: organization.id)
      expect do
        instance.perform(user.id, organization2.id, bike_sticker_batch.id, bike_sticker2.id, bike_sticker3.id)
      end.to change(BikeStickerUpdate, :count).by 2
      expect(bike_sticker1.reload.bike_sticker_updates.count).to eq 0

      # Running again doesn't do anything!
      expect do
        instance.perform(user.id, organization2.id, bike_sticker_batch.id, bike_sticker2.id, bike_sticker3.id)
      end.to change(BikeStickerUpdate, :count).by 0

      expect(bike_sticker2.reload.bike_sticker_updates.count).to eq 2
      expect(bike_sticker2.organization_id).to eq organization2.id
      expect(bike_sticker2.user_id).to eq user2.id
      expect(bike_sticker2.claimed?).to be_truthy
      bike_sticker_update = bike_sticker2.bike_sticker_updates.last
      expect(bike_sticker_update.user_id).to eq user.id
      expect(bike_sticker_update.kind).to eq "admin_reassign"
      expect(bike_sticker_update.creator_kind).to eq "creator_user"
      expect(bike_sticker_update.organization_kind).to eq "primary_organization"
      # And the other sticker is updated as well
      expect(bike_sticker3.reload.bike_sticker_updates.count).to eq 1
      expect(bike_sticker3.organization_id).to eq organization2.id
      expect(bike_sticker_update.user_id).to eq user.id
      expect(bike_sticker_update.kind).to eq "admin_reassign"
      expect(bike_sticker_update.creator_kind).to eq "creator_user"
      expect(bike_sticker_update.organization_kind).to eq "primary_organization"
      # Test that the admin_reassign doesn't change what happens when claimed
      bike_sticker3.claim(user: user2, bike: bike)
      bike_sticker_update_claim = bike_sticker3.bike_sticker_updates.last
      expect(bike_sticker_update_claim.user_id).to eq user2.id
      expect(bike_sticker_update_claim.organization_id).to be_blank
      expect(bike_sticker_update_claim.bike_id).to eq bike.id
      expect(bike_sticker_update_claim.kind).to eq "initial_claim"
      expect(bike_sticker_update_claim.creator_kind).to eq "creator_user"
      expect(bike_sticker_update_claim.organization_kind).to eq "no_organization"
    end
  end
end
