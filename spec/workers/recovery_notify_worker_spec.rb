require 'spec_helper'

describe RecoveryNotifyWorker do
  it { should be_processed_in :notify }

  it "enqueues another awesome job" do
    RecoveryNotifyWorker.perform_async
    expect(RecoveryNotifyWorker).to have_enqueued_job
  end

  xit "posts to the recovery app with sharing" do
    # WE AREN'T ACTUALLY USING THIS ANYMORE
    # Sidekiq::Testing.inline! do
      bike = FactoryGirl.create(:stolen_bike)
      stolen_record = bike.current_stolen_record
      stolen_record.can_share_recovery = true
      stolen_record.date_recovered = Time.now
      stolen_record.recovered_description = "Lorem ipsum"
      stolen_record.index_helped_recovery = true
      stolen_record.recovery_tweet = "The BikeIndex is awesome and someone helped me find my bike!"
      stolen_record.recovery_share = "Some guy named Poopypants found my bike on Craigslist and posted on the BikeIndex and I called the police who checked out my BikeIndex page and went to the Craigslister and got my bike back"
      stolen_record.current = false
      stolen_record.save
      bike.save
      work = RecoveryNotifyWorker.new
      work.perform(stolen_record.id)
      stolen_record.recovery_share.should be_present
      stolen_record.recovery_tweet.should be_present
      # stolen_record.reload.recovery_posted.should be_true
    end
  # end

end
