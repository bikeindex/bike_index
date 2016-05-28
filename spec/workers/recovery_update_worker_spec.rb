require 'spec_helper'

describe RecoveryUpdateWorker do
  it { is_expected.to be_processed_in :updates }

  it 'enqueues another awesome job' do
    RecoveryUpdateWorker.perform_asynchronous
    expect(RecoveryUpdateWorker).to have_enqueued_job
  end

  it 'actuallies do things correctly' do
    Sidekiq::Testing.inline! do
      bike = FactoryGirl.create(:bike)
      stolenRecord = FactoryGirl.create(:stolenRecord, bike: bike)
      bike.update_attribute :stolen, true
      recovery_request = {
        request_type: 'bike_recovery',
        user_id: 69,
        request_bike_id: bike.id,
        request_reason: 'Some reason',
        index_helped_recovery: 'true',
        can_share_recovery: 'false'
      }
      RecoveryUpdateWorker.perform_asynchronous(stolenRecord.id, recovery_request.as_json)
      expect(bike.current_stolenRecord).not_to be_present
      expect(stolenRecord.reload.date_recovered).to be_present
      expect(stolenRecord.index_helped_recovery).to be_truthy
      expect(stolenRecord.can_share_recovery).to be_falsey
    end
  end
end
