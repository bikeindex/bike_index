require 'spec_helper'

describe EmailConfirmationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends a welcome email' do
    user = FactoryGirl.create(:user)
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end

  it 'deletes user if email is invalid' do
    user = FactoryGirl.create(:user)
    user.update(email: 'notaemail@fakeonotreal.blorgh')
    EmailConfirmationWorker.new.perform(user.id)
    expect(User.count).to be_zero
  end
end
