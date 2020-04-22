require 'rails_helper'

RSpec.describe ImpoundRecordUpdate, type: :model do
  describe "validations" do
    let(:impound_record) { FactoryBot.create(:impound_record) }
    let(:user) { impound_record.user }
    let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, user: user, kind: "retrieved_by_user") }
    it "is valid" do
      expect(impound_record.active?).to be_truthy
      expect(impound_record.resolved?).to be_falsey
      impound_record_update.save
      impound_record.reload
      expect(impound_record.impound_record_updates.pluck(:id)).to eq([impound_record_update.id])
      expect(impound_record.status).to eq "retrieved_by_user"
    end
  end
end
