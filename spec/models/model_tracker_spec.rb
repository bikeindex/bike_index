require "rails_helper"

RSpec.describe ModelTracker, type: :model do
  describe "factory" do
    let(:model_tracker) { FactoryBot.create(:model_tracker) }
    it "is valid" do
      expect(model_tracker).to be_valid
    end
  end

  describe "calculated_certification_status" do
    let(:model_tracker) { FactoryBot.create(:model_tracker) }
    let!(:model_attestation) { FactoryBot.create(:model_attestation, model_tracker: model_tracker, kind: :certification_proof_url) }
    it "returns the most important attestation" do
      expect(model_tracker.reload.send(:calculated_certification_status)).to be_nil

      FactoryBot.create(:model_attestation, model_tracker: model_tracker, kind: :certified_by_manufacturer)
      expect(model_tracker.reload.send(:calculated_certification_status)).to eq "certified_by_manufacturer"

      FactoryBot.create(:model_attestation, model_tracker: model_tracker, kind: :certified_by_trusted_org)
      expect(model_tracker.reload.send(:calculated_certification_status)).to eq "certified_by_trusted_org"

      FactoryBot.create(:model_attestation, model_tracker: model_tracker, kind: :uncertified_by_trusted_org)
      expect(model_tracker.reload.send(:calculated_certification_status)).to eq "uncertified_by_trusted_org"

      # It assigns on save
      model_tracker.update(updated_at: Time.current)
      expect(model_tracker.certification_status).to eq "uncertified_by_trusted_org"
    end
  end
end
