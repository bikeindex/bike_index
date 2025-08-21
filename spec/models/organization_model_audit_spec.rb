require "rails_helper"

RSpec.describe OrganizationModelAudit, type: :model do
  let(:model_audit) { FactoryBot.create(:model_audit) }

  describe "factory" do
    let(:organization_model_audit) { FactoryBot.create(:organization_model_audit) }
    it "is valid" do
      expect(organization_model_audit).to be_valid
      expect(organization_model_audit.certification_status).to be_nil
      expect(organization_model_audit.bikes_count).to eq 0
    end
  end

  describe "calculated_certification_status" do
    let!(:model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit, kind: certification_status) }
    let(:certification_status) { "uncertified_by_trusted_org" }
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_model_audit) { FactoryBot.create(:organization_model_audit, model_audit: model_audit, organization: organization) }
    before { model_audit.update(updated_at: Time.current) } # Reset the model_audit to be current status
    it "is model_audit's status" do
      expect(organization_model_audit.model_audit).to eq model_audit
      expect(organization_model_audit.send(:calculated_certification_status)).to eq certification_status
      expect(organization_model_audit.organization_model_attestations.pluck(:id)).to eq([])
      expect(organization_model_audit.certification_status).to eq certification_status
    end
    context "with organization attestation" do
      let(:certification_status) { "certification_proof_url" }
      let(:organization_model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :uncertified_by_trusted_org, organization: organization) }
      it "is the organization_model_attestation status" do
        expect(organization_model_attestation).to be_valid
        expect(organization_model_audit.organization_model_attestations.pluck(:id)).to eq([organization_model_attestation.id])
        expect(organization_model_audit.certification_status).to eq "uncertified_by_your_org"
        expect(organization_model_attestation.replaced).to be_falsey
        expect(model_audit.reload.send(:calculated_certification_status)).to eq "uncertified_by_trusted_org"
        # And replace it
        Sidekiq::Job.clear_all
        expect {
          FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certified_by_trusted_org, organization: organization)
        }.to change(UpdateModelAuditJob.jobs, :count).by 1
        UpdateModelAuditJob.drain
        expect(organization_model_audit.reload.certification_status).to eq "certified_by_your_org"
        expect(model_audit.reload.certification_status).to eq "certified_by_trusted_org"
        expect(organization_model_attestation.reload.replaced).to be_truthy
      end
    end
  end

  describe "bikes" do
    let!(:bike) { FactoryBot.create(:bike_organized, model_audit_id: model_audit.id) }
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_model_audit) { FactoryBot.create(:organization_model_audit, model_audit: model_audit, organization: organization) }
    let!(:bike_organized) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let!(:bike_match) { FactoryBot.create(:bike_organized, creation_organization: organization, model_audit_id: model_audit.id) }
    it "is the organization bikes" do
      expect(model_audit.reload.bikes.pluck(:id)).to match_array([bike.id, bike_match.id])
      expect(organization.reload.bikes.pluck(:id)).to match_array([bike_organized.id, bike_match.id])
      expect(organization_model_audit.reload.bikes.pluck(:id)).to eq([bike_match.id])
    end
  end

  describe "missing_for?" do
    let(:model_audit) { FactoryBot.create(:model_audit) }
    it "is false" do
      expect(OrganizationModelAudit.missing_for?(model_audit)).to be_falsey
    end
    context "with an enabled organization that doesn't have a matching model_audit" do
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["model_audits"]) }
      it "is truthy" do
        expect(OrganizationModelAudit.missing_for?(model_audit)).to be_truthy
      end
    end
    context "with an organization_model_audit" do
      let!(:organization_model_audit) { FactoryBot.create(:organization_model_audit) }
      it "is truthy" do
        expect(Organization.with_enabled_feature_slugs("model_audits").pluck(:id)).to eq([])
        expect(OrganizationModelAudit.missing_for?(model_audit)).to be_truthy
      end
    end
  end
end
