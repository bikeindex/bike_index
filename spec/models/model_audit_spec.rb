require "rails_helper"

RSpec.describe ModelAudit, type: :model do
  describe "factory" do
    let(:model_audit) { FactoryBot.create(:model_audit) }
    it "is valid" do
      expect(model_audit).to be_valid
    end
    context "case_sensitive" do
      let(:model_audit_dupe) { FactoryBot.build(:model_audit, manufacturer: model_audit.manufacturer, frame_model: model_audit.frame_model.upcase) }
      it "doesn't duplicate" do
        expect(model_audit).to be_valid
        expect(model_audit_dupe).to_not be_valid
        expect(model_audit_dupe.errors.full_messages).to eq(["Frame model has already been taken"])
      end
    end
  end

  describe "calculated_certification_status" do
    let(:model_audit) { FactoryBot.create(:model_audit) }
    let!(:model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certification_proof_url) }
    it "returns the most important attestation" do
      expect(model_audit.reload.send(:calculated_certification_status)).to be_nil

      FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certified_by_manufacturer)
      expect(model_audit.reload.send(:calculated_certification_status)).to eq "certified_by_manufacturer"

      FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certified_by_trusted_org)
      expect(model_audit.reload.send(:calculated_certification_status)).to eq "certified_by_trusted_org"

      FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :uncertified_by_trusted_org)
      expect(model_audit.reload.send(:calculated_certification_status)).to eq "uncertified_by_trusted_org"

      # It assigns on save
      model_audit.update(updated_at: Time.current)
      expect(model_audit.certification_status).to eq "uncertified_by_trusted_org"
    end
  end
end
