require "rails_helper"

RSpec.describe ImpoundRecord, type: :model do
  describe "validations" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization, kind: "bike_depot") }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    it "marks the bike impounded only once" do
      expect(organization.can_impound?).to be_truthy
      expect(user.can_impound?).to be_truthy
      expect(bike.impounded?).to be_falsey
      bike.impound_records.create(user: user, bike: bike, organization: organization)
      bike.reload
      expect(bike.impounded?).to be_truthy
      expect(bike.impound_records.count).to eq 1
      impound_record = bike.impound_records.first
      expect(impound_record.organization).to eq organization
      expect(impound_record.user).to eq user
      expect(impound_record.current?).to be_truthy

      new_impound_record = bike.impound(user: user)
      bike.reload
      expect(bike.impound_records.count).to eq 1
      expect(new_impound_record.errors.full_messages.join).to match(/already impounded/)
    end
    context "user not authorized" do
      let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
      it "does not impound" do
        expect(organization.can_impound?).to be_truthy
        expect(user.can_impound?).to be_falsey
        expect(bike.impounded?).to be_falsey
        impound_record = bike.impound_records.create(user: user, bike: bike, organization: organization)
        bike.reload
        expect(bike.impounded?).to be_falsey
        expect(impound_record.errors.full_messages).to match(/authorized/)
      end
    end
    context "user loses authorization" do
      let!(:impound_record) { FactoryBot.create(:impound_record, user: user, bike: bike) }
      it "record is still valid and updateable" do
        expect(bike.impounded?).to be_truthy
        user.memberships.first.destroy
        user.reload
        expect(user.can_impound?).to be_falsey
        expect(impound_record.valid?).to be_truthy
        impound_record.mark_retrieved
        impound_record.reload
        expect(impound_record.retrieved?).to be_truthy
      end
    end
    context "retrieved bike" do
      let(:retrieved_at) { Time.current - 1.minute }
      let!(:impound_record) { FactoryBot.create(:impound_record, user: user, bike: bike, retrieved_at: retrieved_at) }
      it "re-retrieving doesn't alter time, can be re-impounded" do
        impound_record.mark_retrieved
        impound_record.reload
        expect(impound_record.retrieved_at).to be_within(1.second).of retrieved_at
        bike.reload
        expect(bike.impounded?).to be_falsey
        bike.impound_records.create(user: user, bike: bike, organization: organization)
        bike.reload
        expect(bike.impounded?).to be_truthy
        expect(bike.impound_records.count).to eq 2
        # And make sure we can make 2 retrieved records
        bike.impound_records.current.last.mark_retrieved
        bike.reload
        expect(bike.impounded?).to be_falsey
        expect(bike.impound_records.count).to eq 2
      end
    end
  end
end
