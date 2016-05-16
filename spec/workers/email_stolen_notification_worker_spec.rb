require 'spec_helper'

describe EmailStolenNotificationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends an email' do
    stolenNotification = FactoryGirl.create(:stolenNotification)
    ActionMailer::Base.deliveries = []
    EmailStolenNotificationWorker.new.perform(stolenNotification.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
