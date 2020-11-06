require 'rails_helper'

RSpec.describe OwnershipClaim, type: :model do
  describe "factory" do
    let(:ownership_claim) { FactoryBot.create(:ownership_claim) }
    it "is valid" do
      expect(ownership_claim).to be_valid
    end
    context "with_stolen_record" do
      let(:ownership_claim) { FactoryBot.create(:ownership_claim_with_stolen_record) }
      it "is valid" do
        expect(ownership_claim).to be_valid
        expect(ownership_claim.stolen_record_bike).to be_present
        expect(ownership_claim.stolen_record_bike.user).to eq ownership_claim.user
      end
    end
  end
end
