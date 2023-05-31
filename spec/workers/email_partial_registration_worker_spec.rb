require "rails_helper"

RSpec.describe EmailPartialRegistrationWorker, type: :job do
  it "sends a partial registration email" do
    b_param = FactoryBot.create(:b_param)
    expect(b_param.creator_id).to be_present
    expect(Notification.count).to eq 0
    ActionMailer::Base.deliveries = []
    EmailPartialRegistrationWorker.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    exect(Notification.count).to eq 1
    notification = Notification.last
    expect(notification.notifiable).to eq b_param
    # expect(notification.creator_id).to eq b_param.creator_id
    expect(notification.kind).to eq "partial_registration"
  end
end
