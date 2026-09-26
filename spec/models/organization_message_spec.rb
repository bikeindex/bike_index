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

  describe "for?" do
    it "is for a with-owner bike registered with the organization" do
      expect(OrganizationMessage.for?(bike:, organization:)).to be_truthy
      expect(OrganizationMessage.for?(bike:, organization: FactoryBot.create(:organization))).to be_falsey
    end

    context "impounded" do
      let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization) }
      it "isn't" do
        expect(OrganizationMessage.for?(bike: bike.reload, organization:)).to be_falsey
      end
    end
  end
end
