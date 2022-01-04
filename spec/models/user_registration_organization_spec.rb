require 'rails_helper'

RSpec.describe UserRegistrationOrganization, type: :model do
  describe "factories" do
    let(:user_registration_organization) { FactoryBot.create(:user_registration_organization) }
    it "is valid" do
      expect(user_registration_organization).to be_valid
      expect(user_registration_organization.all_bikes?).to be_falsey
      expect(user_registration_organization.manages_information?).to be_falsey
    end
  end

  describe "manages_information?" do
    let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, registration_info: {student_id: "fadf"}) }
    it "is truthy" do
      expect(user_registration_organization.reload.registration_info).to be_present
      expect(user_registration_organization.all_bikes?).to be_falsey
      expect(user_registration_organization.manages_information?).to be_truthy
    end
    context "organization with registration fields" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["reg_organization_affiliation"]) }
      let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, organization: organization) }
      it "is truthy" do
        expect(user_registration_organization.reload.registration_info).to be_blank
        expect(user_registration_organization.all_bikes?).to be_truthy
        expect(user_registration_organization.manages_information?).to be_truthy
      end
    end
  end
end
