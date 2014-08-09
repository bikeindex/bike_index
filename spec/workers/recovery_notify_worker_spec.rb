require 'spec_helper'

describe RecoveryNotifyWorker do
  it { should be_processed_in :notify }

  it "enqueues another awesome job" do
    RecoveryNotifyWorker.perform_async
    expect(RecoveryNotifyWorker).to have_enqueued_job
  end
  it "should post a thing to the api with no sharing" do 

  it "should post to the recovery app with no sharing" do 
    Sidekiq::Testing.inline!
    bike = FactoryGirl.create(:bike)
    stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
    bike.current_stolen_record.can_share_recovery.should be_false
    bike.current_stolen_record.recovery_posted.should be_true
  end

  it "should post to the recovery app with sharing" do 
    Sidekiq::Testing.inline!
    bike = FactoryGirl.create(:bike)
    stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
    bike.current_stolen_record.can_share_recovery.should be_false
    bike.current_stolen_record.recovery_posted.should be_true
  end

end
