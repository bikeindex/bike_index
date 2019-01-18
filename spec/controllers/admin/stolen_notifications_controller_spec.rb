require 'spec_helper'

describe Admin::StolenNotificationsController do
  describe 'index' do
    before do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :index
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
    it { is_expected.not_to set_flash }
  end

  describe 'show' do
    before do
      stolen_notification = FactoryBot.create(:stolen_notification)
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :show, id: stolen_notification.id
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:show) }
    it { is_expected.not_to set_flash }
  end

  describe 'resend' do
    it 'resends the stolen notification' do
      Sidekiq::Worker.clear_all
      sender = FactoryBot.create(:user)
      admin = FactoryBot.create(:admin)
      stolen_notification = FactoryBot.create(:stolen_notification, sender: sender)
      # pp expect(EmailStolenNotificationWorker).to have_enqueued_sidekiq_job
      set_current_user(admin)
      expect do
        get :resend, id: stolen_notification.id
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end

    it 'redirects if the stolen notification has already been sent' do
      Sidekiq::Worker.clear_all
      sender = FactoryBot.create(:user)
      admin = FactoryBot.create(:admin)
      stolen_notification = FactoryBot.create(:stolen_notification, sender: sender)
      stolen_notification.update_attribute :send_dates, [69].to_json
      set_current_user(admin)
      expect do
        get :resend, id: stolen_notification.id
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(0)
      expect(response).to redirect_to(:admin_stolen_notification)
    end

    it 'resends if the stolen notification has already been sent if we say pretty please' do
      Sidekiq::Worker.clear_all
      sender = FactoryBot.create(:user)
      admin = FactoryBot.create(:admin)
      stolen_notification = FactoryBot.create(:stolen_notification, sender: sender)
      stolen_notification.update_attribute :send_dates, [69].to_json
      set_current_user(admin)
      expect do
        get :resend, id: stolen_notification.id, pretty_please: true
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end
  end
end
