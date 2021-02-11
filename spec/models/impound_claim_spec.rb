require "rails_helper"

RSpec.describe ImpoundClaim, type: :model do
  describe "factory" do
    let(:impound_claim) { FactoryBot.create(:impound_claim) }
    it "is valid" do
      expect(impound_claim).to be_valid
      expect(impound_claim.bike_claimed).to be_present
      expect(impound_claim.impound_record.organized?).to be_truthy
      expect(impound_claim.impound_record.creator_public_display_name).to eq impound_claim.organization.name
    end
    context "unorganized" do
      let(:impound_record) { FactoryBot.create(:impound_record) }
      let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record) }
      it "is valid" do
        expect(impound_claim).to be_valid
        expect(impound_claim.bike_claimed).to be_present
        expect(impound_record.organized?).to be_falsey
        expect(impound_record.creator_public_display_name).to eq "bike finder"
      end
    end
    context "with_stolen_record" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, organization: organization) }
      it "is valid" do
        expect(impound_claim).to be_valid
        expect(impound_claim.bike_claimed).to be_present
        expect(impound_claim.bike_submitting.user&.id).to eq impound_claim.user.id
        expect(impound_claim.stolen_record.user&.id).to eq impound_claim.user.id
        expect(impound_claim.impound_record.organization&.id).to eq organization.id
        expect(organization.public_impound_bikes?).to be_falsey # There can be claims on records, even if organization isn't enabled
      end
    end
    describe "impound_claim_resolved" do
      let(:impound_claim) { FactoryBot.create(:impound_claim_resolved) }
      it "is valid" do
        impound_claim.reload
        expect(impound_claim.status).to eq "retrieved"
        expect(impound_claim.impound_record.status).to eq "retrieved_by_owner"
        expect(impound_claim.send(:calculated_status)).to eq "retrieved"
        expect(impound_claim.resolved?).to be_truthy
        expect(impound_claim.resolved_at).to be_within(1).of Time.current
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
      expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
      impound_claim.reload
      expect(impound_claim.bike_submitting&.id).to eq bike.id
      expect(impound_claim.bike_submitting_images.pluck(:id)).to eq([public_image_private.id, public_image.id])
    end
  end
end
