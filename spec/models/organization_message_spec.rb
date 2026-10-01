require "rails_helper"

RSpec.describe OrganizationMessage, type: :model do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications]) }
  let(:sender) { FactoryBot.create(:organization_user, organization:) }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "owner@bikeindex.org") }
  let(:organization_message) { OrganizationMessage.new(bike:, organization:, sender:, message: "Hi") }

  describe "create" do
    it "sends to the unclaimed owner's email" do
      expect {
        expect(organization_message.save).to be_truthy
      }.to change(EmailJobs::OrganizationMessageJob.jobs, :count).by(1)
      expect(organization_message).to have_attributes(receiver_id: nil, receiver_email: "owner@bikeindex.org")
    end

    context "phone registration" do
      let(:bike) { FactoryBot.create(:bike_organized, :phone_registration, creation_organization: organization) }
      it "is invalid" do
        expect(OrganizationMessage.for?(bike:, organization:)).to be_falsey
        expect(organization_message.save).to be_falsey
        expect(organization_message.errors.full_messages).to eq(["sender can't message the owner of this bike"])
      end
    end

    context "sender not a member" do
      let(:sender) { FactoryBot.create(:user_confirmed) }
      it "is invalid" do
        expect(organization_message.save).to be_falsey
        expect(organization_message.errors.full_messages).to eq(["sender can't message the owner of this bike"])
      end
    end
  end

  describe "unavailable_reason" do
    it "is nil for a with-owner bike registered with the organization" do
      expect(OrganizationMessage.unavailable_reason(bike:, organization:)).to be_nil
      expect(OrganizationMessage.for?(bike:, organization:)).to be_truthy
      expect(OrganizationMessage.unavailable_reason(bike:, organization: FactoryBot.create(:organization))).to eq :not_registered_with_organization
    end

    context "stolen" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization) }
      it "is stolen" do
        expect(OrganizationMessage.unavailable_reason(bike: bike.reload, organization:)).to eq :stolen
        expect(OrganizationMessage.for?(bike:, organization:)).to be_falsey
      end
    end

    context "impounded" do
      let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization) }
      it "is not with owner" do
        expect(OrganizationMessage.unavailable_reason(bike: bike.reload, organization:)).to eq :not_with_owner
      end
    end

    context "phone registration" do
      let(:bike) { FactoryBot.create(:bike_organized, :phone_registration, creation_organization: organization) }
      it "is phone_registration" do
        expect(OrganizationMessage.unavailable_reason(bike:, organization:)).to eq :phone_registration
      end
    end
  end
end
