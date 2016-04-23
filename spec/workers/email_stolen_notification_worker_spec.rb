require 'spec_helper'

describe EmailStolenNotificationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends an email' do
    stolen_notification = FactoryGirl.create(:stolen_notification)
    ActionMailer::Base.deliveries = []
    EmailStolenNotificationWorker.new.perform(stolen_notification.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
