require "rails_helper"

RSpec.describe BikeDisplayer do
  describe "display_impound_claim?" do
    let(:bike) { Bike.new }
    let(:admin) { User.new(superuser: true) }
    let(:owner) { User.new }
    before { allow(bike).to receive(:owner) { owner } }
    it "is falsey if bike doesn't have impounded" do
      expect(BikeDisplayer.display_impound_claim?(bike)).to be_falsey
    end
    context "impound bike" do
      let(:impound_record) { ImpoundRecord.new(bike: bike) }
      before { allow(bike).to receive(:current_impound_record) { impound_record } }
      it "is truthy" do
        expect(BikeDisplayer.display_impound_claim?(bike)).to be_truthy
        expect(BikeDisplayer.display_impound_claim?(bike, User.new)).to be_truthy
        expect(BikeDisplayer.display_impound_claim?(bike, admin)).to be_truthy
        expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_falsey
      end
    end
    context "impound_claim for bike" do
      let(:owner) { FactoryBot.create(:user_confirmed) }
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
      let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, bike: bike, user: owner) }
      let(:bike_claimed) { impound_claim.bike_claimed }
      it "is expected values" do
        bike.reload
        expect(bike.authorized?(owner)).to be_truthy
        expect(impound_claim.resolved?).to be_falsey
        expect(impound_claim.bike_submitting&.id).to eq bike.id
        expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
        expect(BikeDisplayer.display_impound_claim?(bike)).to be_falsey
        expect(BikeDisplayer.display_impound_claim?(bike, User.new)).to be_falsey
        expect(BikeDisplayer.display_impound_claim?(bike, admin)).to be_falsey
        expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_falsey
        expect(bike_claimed.id).to_not eq bike.id
        expect(BikeDisplayer.display_impound_claim?(bike_claimed)).to be_truthy
      end
      context "retrieved" do
        let(:impound_record) { FactoryBot.create(:impound_record_resolved, status: "retrieved_by_owner", bike: bike) }
        let(:organization) { impound_record.organization }
        let!(:impound_claim) do
          FactoryBot.create(:impound_claim_resolved, :with_stolen_record,
            bike: bike,
            user: owner,
            impound_record: impound_record,
            organization: organization)
        end
        it "is expected values" do
          bike.reload
          impound_claim.reload
          expect(impound_claim.resolved?).to be_truthy
          expect(bike.authorized?(owner)).to be_truthy
          expect(bike.current_impound_record_id).to be_blank
          expect(impound_claim.user_id).to eq owner.id
          expect(impound_claim.bike_submitting&.id).to eq bike.id
          expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
          expect(BikeDisplayer.display_impound_claim?(bike)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike, User.new)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike, admin)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_falsey

          expect(impound_claim.bike_submitting.id).to eq bike_claimed.id
          expect(BikeDisplayer.display_impound_claim?(bike_claimed)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike_claimed, User.new)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike_claimed, admin)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike_claimed, owner)).to be_falsey
        end
      end
    end
  end

  describe "display_contact_owner?" do
    let(:bike) { Bike.new }
    let(:admin) { User.new(superuser: true) }
    let(:owner) { User.new }
    before { allow(bike).to receive(:owner) { owner } }
    it "is falsey if bike doesn't have stolen record" do
      expect(bike.contact_owner?).to be_falsey
      expect(bike.contact_owner?(User.new)).to be_falsey
      expect(bike.contact_owner?(admin)).to be_truthy
      expect(BikeDisplayer.display_contact_owner?(bike)).to be_falsey
    end
    context "stolen bike" do
      let(:bike) { Bike.new(status: "status_stolen", current_stolen_record: StolenRecord.new) }
      it "is truthy" do
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(User.new)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, admin)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, owner)).to be_truthy
      end
    end
  end

  describe "display_sticker_edit?" do
    let(:bike) { Bike.new }
    let(:owner) { User.new }
    it "is falsey if bike doesn't have stolen record" do
      allow(bike).to receive(:owner) { owner }
      expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_falsey
      expect(BikeDisplayer.display_sticker_edit?(bike, User.new(superuser: true))).to be_truthy
    end
    context "organization is a bike_sticker child" do
      let!(:organization) { FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, enabled_feature_slugs: %[regional_bike_counts bike_stickers]) }
      let(:organization2) { FactoryBot.create(:organization, :in_nyc) }
      let(:bike) { FactoryBot.create(:bike_organized, organization: organization2, can_edit_claimed: false) }
      it "is truthy" do
        organization2.reload
        expect(organization2.enabled_feature_slugs).to eq(%w[bike_stickers reg_bike_sticker])
        bike.reload
        expect(bike.organizations.pluck(:id)).to eq([organization2.id])
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
      end
    end
    context "bike has sticker, other user bike has sticker" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:owner) { bike.owner }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike, user: user) }
      let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
      let(:bike_other) { FactoryBot.create(:bike) }
      it "is truthy" do
        bike.reload
        expect(bike.owner).to eq owner
        expect(bike.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
        bike2.reload
        expect(bike2.bike_stickers.pluck(:id)).to eq([])
        expect(BikeDisplayer.display_sticker_edit?(bike2, owner)).to be_truthy
        bike_sticker.claim(bike: bike_other)
        bike.reload
        expect(bike.bike_stickers.pluck(:id)).to eq([])
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
        bike2.reload
        expect(BikeDisplayer.display_sticker_edit?(bike2, owner)).to be_truthy
      end
    end
    context "user can't add more stickers" do
      it "is falsey"
    end
  end
end
