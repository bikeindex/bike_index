# == Schema Information
#
# Table name: impound_claims
#
#  id                 :bigint           not null, primary key
#  message            :text
#  resolved_at        :datetime
#  response_message   :text
#  status             :integer
#  submitted_at       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  bike_claimed_id    :bigint
#  bike_submitting_id :bigint
#  impound_record_id  :bigint
#  organization_id    :bigint
#  stolen_record_id   :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_impound_claims_on_bike_claimed_id     (bike_claimed_id)
#  index_impound_claims_on_bike_submitting_id  (bike_submitting_id)
#  index_impound_claims_on_impound_record_id   (impound_record_id)
#  index_impound_claims_on_organization_id     (organization_id)
#  index_impound_claims_on_stolen_record_id    (stolen_record_id)
#  index_impound_claims_on_user_id             (user_id)
#
require "rails_helper"

RSpec.describe ImpoundClaim, type: :model do
  describe "factory" do
    let(:impound_claim) { FactoryBot.create(:impound_claim) }
    it "is valid" do
      expect(impound_claim).to be_valid
      expect(impound_claim.bike_claimed).to be_present
      expect(impound_claim.impound_record.organized?).to be_truthy
      expect(impound_claim.impound_record.creator_public_display_name).to eq impound_claim.organization.name
    end
    context "unorganized" do
      let(:impound_record) { FactoryBot.create(:impound_record) }
      let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record) }
      it "is valid" do
        expect(impound_claim).to be_valid
        expect(impound_claim.status_humanized).to eq "pending"
        expect(impound_claim.bike_claimed).to be_present
        expect(impound_record.organized?).to be_falsey
        expect(impound_record.creator_public_display_name).to eq "bike finder"
        expect(impound_claim.claim_kind_humanized).to eq "found bike claim"
      end
    end
    context "with_stolen_record" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, status: "submitting", organization: organization) }
      it "is valid" do
        expect(impound_claim).to be_valid
        expect(impound_claim.status_humanized).to eq "submitted"
        expect(impound_claim.bike_claimed).to be_present
        expect(impound_claim.bike_submitting.user&.id).to eq impound_claim.user.id
        expect(impound_claim.stolen_record.user&.id).to eq impound_claim.user.id
        expect(impound_claim.impound_record.organization&.id).to eq organization.id
        expect(organization.public_impound_bikes?).to be_falsey # There can be claims on records, even if organization isn't enabled
        expect(ImpoundClaim.involving_bike_id(impound_claim.bike_claimed_id).pluck(:id)).to eq([impound_claim.id])
        expect(ImpoundClaim.involving_bike_id(impound_claim.bike_submitting_id).pluck(:id)).to eq([impound_claim.id])
      end
    end
    describe "impound_claim_resolved" do
      let(:impound_claim) { FactoryBot.create(:impound_claim_resolved) }
      it "is valid" do
        impound_claim.reload
        expect(impound_claim.status).to eq "retrieved"
        expect(impound_claim.impound_record.status).to eq "retrieved_by_owner"
        expect(impound_claim.send(:calculated_status)).to eq "retrieved"
        expect(impound_claim.resolved?).to be_truthy
        expect(impound_claim.resolved_at).to be_within(1).of Time.current
      end
    end
  end

  describe "bike_submitting_images" do
    let(:bike) { FactoryBot.create(:bike, cycle_type: "trailer") }
    let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, bike: bike) }
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, listing_order: 4) }
    let!(:public_image_private) { FactoryBot.create(:public_image, imageable: bike, is_private: true, listing_order: 1) }
    it "returns private and non-private" do
      bike.reload
      expect(bike.public_images.pluck(:id)).to eq([public_image.id])
      expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
      impound_claim.reload
      expect(impound_claim.bike_submitting&.id).to eq bike.id
      expect(impound_claim.bike_submitting_images.pluck(:id)).to eq([public_image_private.id, public_image.id])
      expect(impound_claim.kind).to eq "impounded"
      expect(impound_claim.organized?).to be_truthy
      expect(impound_claim.claim_kind_humanized).to eq "impounded bike trailer claim"
    end
  end

  describe "impound_record_email" do
    let(:user) { FactoryBot.create(:user, email: "example@stuff.com") }
    let(:impound_record) { FactoryBot.create(:impound_record, user: user) }
    let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record) }
    it "returns user email" do
      expect(impound_claim.impound_record_email).to eq "example@stuff.com"
    end
    context "organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:organization_user, organization: organization, email: "example@stuff.com") }
      let(:impound_record) { FactoryBot.create(:impound_record, :with_organization, user: user, organization: organization) }
      it "returns user email" do
        organization.fetch_impound_configuration
        expect(organization.reload.auto_user).to be_blank
        impound_claim.reload
        expect(impound_claim.impound_record_email).to eq "example@stuff.com"
      end
      context "organization with auto_user" do
        let(:organization) { FactoryBot.create(:organization_with_auto_user) }
        it "is auto_user, or impound email" do
          expect(organization.fetch_impound_configuration.email).to be_blank
          expect(organization.reload.auto_user).to be_present
          impound_claim.reload
          expect(impound_claim.impound_record_email).to eq organization.reload.auto_user.email
          organization.impound_configuration.update(email: "new@example.com")
          impound_claim.reload
          expect(impound_claim.impound_record_email).to eq "new@example.com"
        end
      end
    end
  end
end
