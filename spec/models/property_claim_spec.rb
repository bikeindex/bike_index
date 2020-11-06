require 'rails_helper'

RSpec.describe PropertyClaim, type: :model do
  describe "factory" do
    let(:property_claim) { FactoryBot.create(:property_claim) }
    it "is valid" do
      expect(property_claim).to be_valid
    end
    context "with_stolen_record" do
      let(:property_claim) { FactoryBot.create(:property_claim_with_stolen_record) }
      it "is valid" do
        expect(property_claim).to be_valid
        expect(property_claim.stolen_record_bike).to be_present
        expect(property_claim.stolen_record_bike.user).to eq property_claim.user
      end
    end
  end
end
