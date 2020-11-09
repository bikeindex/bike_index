require 'rails_helper'

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
end
