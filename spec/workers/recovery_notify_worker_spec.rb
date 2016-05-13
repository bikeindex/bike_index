require 'spec_helper'

describe RecoveryNotifyWorker do
  it { is_expected.to be_processed_in :notify }

  it 'enqueues another awesome job' do
    RecoveryNotifyWorker.perform_async
    expect(RecoveryNotifyWorker).to have_enqueued_job
  end

  xit 'posts to the recovery app with sharing' do
    # WE AREN'T ACTUALLY USING THIS ANYMORE
    # Sidekiq::Testing.inline! do
    bike = FactoryGirl.create(:stolen_bike)
    stolenRecord = bike.current_stolenRecord
    stolenRecord.can_share_recovery = true
    stolenRecord.date_recovered = Time.now
    stolenRecord.recovered_description = 'Lorem ipsum'
    stolenRecord.index_helped_recovery = true
    stolenRecord.recovery_tweet = 'The BikeIndex is awesome and someone helped me find my bike!'
    stolenRecord.recovery_share = 'Some guy named Poopypants found my bike on Craigslist and posted on the BikeIndex and I called the police who checked out my BikeIndex page and went to the Craigslister and got my bike back'
    stolenRecord.current = false
    stolenRecord.save
    bike.save
    work = RecoveryNotifyWorker.new
    work.perform(stolenRecord.id)
    expect(stolenRecord.recovery_share).to be_present
    expect(stolenRecord.recovery_tweet).to be_present
    # stolenRecord.reload.recovery_posted.should be_true
  end
  # end
end
