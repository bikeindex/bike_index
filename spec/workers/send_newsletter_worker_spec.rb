require 'spec_helper'

# This entire thing is commented out because it requires putting in the API key and the template ID for Sparkpost - which we don't want to expose
# So rather than doing that, just run this if it needs to run and manually put in the ENV variables

describe SendNewsletterWorker do
  it { is_expected.to be_processed_in :notify }
  let(:subject) { SendNewsletterWorker }
  let(:instance) { subject.new }

  context 'no id passed' do
    let(:user) { FactoryGirl.create(:confirmed_user, is_emailable: true, banned: false) }
    let(:user_unemailable) { FactoryGirl.create(:confirmed_user, is_emailable: false) }
    let(:user_banned) { FactoryGirl.create(:confirmed_user, is_emailable: true, banned: true) }
    let(:user_unconfirmed) { FactoryGirl.create(:user, is_emailable: true, banned: false) }
    it 'enqueues sending to emails' do
      expect([user.id, user_unemailable.id, user_banned.id, user_unconfirmed.id].count).to eq 4
      expect(user.confirmed).to be_truthy
      expect(user.is_emailable).to be_truthy
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.fake! do
        expect do
          instance.perform('template_id')
        end.to change(subject.jobs, :count).by 1
        expect(subject.jobs.map { |j| j['args'] }.uniq.flatten).to eq(['template_id', user.id])
      end
    end
  end
end
