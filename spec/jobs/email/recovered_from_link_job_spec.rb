require "rails_helper"

RSpec.describe Email::RecoveredFromLinkJob, type: :job do
  let(:bike) { FactoryBot.create(:stolen_bike) }
  let(:stolen_record) { bike.current_stolen_record }
  before { stolen_record.add_recovery_information }

  it "sends a recovered from link email" do
    ActionMailer::Base.deliveries = []
    Email::RecoveredFromLinkJob.new.perform(stolen_record.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
