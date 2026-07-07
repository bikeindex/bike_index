require "rails_helper"

RSpec.describe Email::WelcomeJob, type: :job do
  it "enqueues listing ordering job" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    Email::WelcomeJob.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end

  context "email banned user" do
    let(:user) { FactoryBot.create(:user) }
    let!(:email_ban) { FactoryBot.create(:email_ban, user:) }
    it "does not send an email" do
      ActionMailer::Base.deliveries = []
      Email::WelcomeJob.new.perform(user.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end
end
