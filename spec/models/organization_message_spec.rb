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
      expect(organization_message).to have_attributes(receiver_id: nil, receiver_email: "owner@bikeindex.org", kind: "general_message")
    end

    context "unknown kind" do
      it "is invalid" do
        organization_message.kind = "e_vehicle_policy_message"
        expect(organization_message.save).to be_falsey
        expect(organization_message.errors.full_messages).to eq(["Kind is not included in the list"])
      end
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

  describe "mail_snippet" do
    let!(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, kind: "general_message", organization:, is_enabled:) }
    let(:is_enabled) { true }
    it "is the organization's enabled snippet of the kind" do
      expect(organization_message.mail_snippet).to eq mail_snippet
      expect(OrganizationMessage.new(organization: FactoryBot.create(:organization)).mail_snippet).to be_nil
    end

    context "disabled" do
      let(:is_enabled) { false }
      it "is nil" do
        expect(organization_message.mail_snippet).to be_nil
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
      it "is available" do
        expect(bike.reload.status).to eq "status_stolen"
        expect(OrganizationMessage.unavailable_reason(bike:, organization:)).to be_nil
      end
    end

    context "impounded" do
      let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization) }
      it "is status" do
        expect(OrganizationMessage.unavailable_reason(bike: bike.reload, organization:)).to eq :status
        expect(OrganizationMessage.for?(bike:, organization:)).to be_falsey
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
