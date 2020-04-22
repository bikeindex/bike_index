require 'rails_helper'

RSpec.describe ImpoundRecordUpdate, type: :model do
  describe "kinds and statuses" do
    it "resolved is resolved" do
      expect(ImpoundRecordUpdate.resolved_kinds).to match_array(ImpoundRecord.resolved_statuses)
    end
  end

  describe "status on impound_record" do
    let(:impound_record) { FactoryBot.create(:impound_record) }
    let(:bike) { FactoryBot.create(:bike) }
    let(:user) { impound_record.user }
    let(:kind) { "retrieved_by_user" }
    let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, user: user, kind: kind) }
    it "marks retrieved_by_user" do
      expect(impound_record.active?).to be_truthy
      expect(impound_record.resolved?).to be_falsey
      impound_record_update.save
      impound_record.reload
      expect(impound_record.impound_record_updates.pluck(:id)).to eq([impound_record_update.id])
      expect(impound_record.status).to eq "retrieved_by_user"
      expect(impound_record.resolved?).to be_truthy
      expect(impound_record.resolved_at).to be_within
    end
    context "removed_from_bike_index" do
      it "deletes" do
        # is deleted from bike index and impound_record is resolved
      end
    end
    context "sold" do
      it "sends to a new owner" do
        # is sold, etc
      end
      context "unregistered_parking_notification" do
        # let(:parking_notification)
        it "sends to a new owner, ensures mark user hidden is off" do
          # parking_notification.reload
          # expect(parking_notification.unregistered_bike).to be_truthy
        end
      end
    end
  end
end
