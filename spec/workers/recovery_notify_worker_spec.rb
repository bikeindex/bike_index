require 'spec_helper'

describe RecoveryNotifyWorker do
  # it { should be_processed_in :notify }

  # it "enqueues another awesome job" do
  #   RecoveryNotifyWorker.perform_async
  #   expect(RecoveryNotifyWorker).to have_enqueued_job
  # end

  it "should post to the recovery app with no sharing" do
    Sidekiq::Testing.inline!
    bike = FactoryGirl.create(:stolen_bike)
    bike.current_stolen_record.can_share_recovery.should be_false
    bike.current_stolen_record.date_recovered = Time.now
    bike.current_stolen_record.recovered_description = "I stole it from myself so it wasn't hard to get it back"
    bike.current_stolen_record.save
    work = RecoveryNotifyWorker.new
    work.perform(bike.current_stolen_record_id)
    bike.reload.current_stolen_record.recovery_posted.should be_true
  end

  it "should post to the recovery app with sharing" do
    Sidekiq::Testing.inline!
    bike = FactoryGirl.create(:stolen_bike)
    bike.current_stolen_record.can_share_recovery = true
    bike.current_stolen_record.date_recovered = Time.now
    bike.current_stolen_record.recovered_description = "Lorem ipsum"
    bike.current_stolen_record.index_helped_recovery = true
    bike.current_stolen_record.recovery_tweet = "The BikeIndex is awesome and someone helped me find my bike!"
    bike.current_stolen_record.recovery_share = "Some guy named Poopypants found my bike on Craigslist and posted on the BikeIndex and I called the police who checked out my BikeIndex page and went to the Craigslister and got my bike back"
    bike.current_stolen_record.save
    work = RecoveryNotifyWorker.new
    work.perform(bike.current_stolen_record_id)
    bike.reload.current_stolen_record.recovery_posted.should be_true
  end

end
