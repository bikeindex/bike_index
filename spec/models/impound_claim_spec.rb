require "rails_helper"

RSpec.describe ImpoundClaim, type: :model do
  describe "factory" do
    let(:impound_claim) { FactoryBot.create(:impound_claim) }
    it "is valid" do
      expect(impound_claim).to be_valid
      expect(impound_claim.bike_claimed).to be_present
    end
    context "with_stolen_record" do
      let(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record) }
      it "is valid" do
        expect(impound_claim).to be_valid
        expect(impound_claim.bike_claimed).to be_present
        expect(impound_claim.bike_submitting.user).to eq impound_claim.user
        expect(impound_claim.stolen_record.user).to eq impound_claim.user
      end
    end
  end

  describe "bike_submitting_images" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, bike: bike) }
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, listing_order: 4) }
    let!(:public_image_private) { FactoryBot.create(:public_image, imageable: bike, is_private: true, listing_order: 1) }
    it "returns private and non-private" do
      bike.reload
      expect(bike.public_images.pluck(:id)).to eq([public_image.id])
      impound_claim.reload
      expect(impound_claim.bike_submitting&.id).to eq bike.id
      expect(impound_claim.bike_submitting_images.pluck(:id)).to eq([public_image_private.id, public_image.id])
    end
  end
end
