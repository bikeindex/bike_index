require 'spec_helper'

describe EmailRecoveredFromLinkWorker do
  it { is_expected.to be_processed_in :notify }
  let(:bike) { FactoryGirl.create(:stolen_bike) }
  let(:stolen_record) { bike.current_stolen_record }
  before { stolen_record.add_recovery_information }

  it 'sends a recovered from link email' do
    EmailRecoveredFromLinkWorker.new.perform(stolen_record.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
