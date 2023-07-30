require "rails_helper"

RSpec.describe EmailPartialRegistrationWorker, type: :job do
  it "sends a partial registration email" do
    b_param = FactoryBot.create(:b_param)
    expect(b_param.creator_id).to be_present
    expect(Notification.count).to eq 0
    ActionMailer::Base.deliveries = []
    EmailPartialRegistrationWorker.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    expect(Notification.count).to eq 1
    notification = Notification.last
    expect(notification.notifiable).to eq b_param
    expect(notification.kind).to eq "partial_registration"
    expect(notification.user_id).to be_blank
    expect(notification.delivery_status).to eq "email_success"
    expect(notification.b_param?).to be_truthy
    expect(notification.calculated_email).to eq b_param.email
  end
end
