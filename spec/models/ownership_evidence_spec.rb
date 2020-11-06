require 'rails_helper'

RSpec.describe OwnershipEvidence, type: :model do
  describe "factory" do
    let(:ownership_evidence) { FactoryBot.create(:ownership_evidence) }
    it "is valid" do
      expect(ownership_evidence).to be_valid
    end
    context "with_stolen_record" do
      let(:ownership_evidence) { FactoryBot.create(:ownership_evidence_with_stolen_record) }
      it "is valid" do
        expect(ownership_evidence).to be_valid
        expect(ownership_evidence.stolen_record_bike).to be_present
        expect(ownership_evidence.stolen_record_bike.user).to eq ownership_evidence.user
      end
    end
  end
end
