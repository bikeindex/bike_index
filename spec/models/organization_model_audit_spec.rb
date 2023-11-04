require 'rails_helper'

RSpec.describe OrganizationModelAudit, type: :model do
  describe "factory" do
    let(:organization_model_audit) { FactoryBot.create(:organization_model_audit) }
    it "is valid" do
      expect(organization_model_audit).to be_valid
      expect(organization_model_audit.certification_status).to eq
    end
  end

  describe "calculated_certification_status" do
  end

  describe "bikes" do
    let(:bike) { FactoryBot.create(:bike_organized, model_audit: model_audit) }
  end
end
