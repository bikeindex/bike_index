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
        expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_truthy
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
        expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_truthy
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
      let(:bike) { Bike.new(stolen: true, current_stolen_record: StolenRecord.new) }
      it "is truthy" do
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(User.new)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, admin)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, owner)).to be_truthy
      end
    end
  end
end
