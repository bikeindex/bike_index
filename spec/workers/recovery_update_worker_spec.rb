require 'spec_helper'

describe RecoveryUpdateWorker do
  it { should be_processed_in :updates }

  it "enqueues another awesome job" do
    RecoveryUpdateWorker.perform_async
    expect(RecoveryUpdateWorker).to have_enqueued_job
  end

  it "should actually do things correctly" do 
    Sidekiq::Testing.inline!
    bike = FactoryGirl.create(:bike)
    stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
    bike.update_attribute :stolen, true
    recovery_request = { 
      request_type: 'bike_recovery',
      user_id: 69,
      request_bike_id: bike.id,
      request_reason: 'Some reason',
      index_helped_recovery: 'true',
      can_share_recovery: 'false'
    }
    RecoveryUpdateWorker.perform_async(stolen_record.id, recovery_request.as_json)
    bike.current_stolen_record.date_recovered.should be_present
    bike.current_stolen_record.recovery_posted.should be_true
    bike.current_stolen_record.index_helped_recovery.should be_true
    bike.current_stolen_record.can_share_recovery.should be_false
  end

end
