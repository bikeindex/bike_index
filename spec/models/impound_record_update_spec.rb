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
    let(:kind) { "retrieved_by_owner" }
    let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, user: user, kind: kind) }
    it "marks retrieved_by_owner" do
      expect(impound_record.active?).to be_truthy
      expect(impound_record.resolved?).to be_falsey
      impound_record_update.save
      impound_record.reload
      expect(impound_record.impound_record_updates.pluck(:id)).to eq([impound_record_update.id])
      expect(impound_record.status).to eq "retrieved_by_owner"
      expect(impound_record.resolved?).to be_truthy
      expect(impound_record.resolved_at).to be_within(1).of Time.current
    end
  end
end
