require "rails_helper"

RSpec.describe EmailPartialRegistrationWorker, type: :job do
  it "sends a partial registration email" do
    b_param = FactoryBot.create(:b_param)
    ActionMailer::Base.deliveries = []
    EmailPartialRegistrationWorker.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
