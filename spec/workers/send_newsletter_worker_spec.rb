require 'spec_helper'

describe SendNewsletterWorker do
  it { is_expected.to be_processed_in :notify }
  let(:subject) { SendNewsletterWorker }
  let(:instance) { subject.new }

  context 'no id passed' do
    let(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: true, banned: false) }
    let(:user_unemailable) { FactoryBot.create(:user_confirmed, notification_newsletters: false) }
    let(:user_banned) { FactoryBot.create(:user_confirmed, notification_newsletters: true, banned: true) }
    let(:user_unconfirmed) { FactoryBot.create(:user, notification_newsletters: true, banned: false) }
    it 'enqueues sending to emails' do
      expect([user.id, user_unemailable.id, user_banned.id, user_unconfirmed.id].count).to eq 4
      expect(user.confirmed).to be_truthy
      expect(user.notification_newsletters).to be_truthy
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
