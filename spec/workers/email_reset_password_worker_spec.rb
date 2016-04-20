require 'spec_helper'

describe EmailResetPasswordWorker do
  it { is_expected.to be_processed_in :notify }

  it "sends a password_reset email" do
    user = FactoryGirl.create(:user)
    EmailResetPasswordWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
