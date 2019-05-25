require "spec_helper"

describe EmailPartialRegistrationWorker do
  it "sends a partial registration email" do
    b_param = FactoryBot.create(:b_param)
    EmailPartialRegistrationWorker.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
