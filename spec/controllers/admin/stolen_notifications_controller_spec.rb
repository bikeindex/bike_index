require 'spec_helper'

describe Admin::StolenNotificationsController do
  describe 'index' do
    before do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
    it { is_expected.not_to set_flash }
  end

  describe 'show' do
    before do
      stolenNotification = FactoryGirl.create(:stolenNotification)
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :show, id: stolenNotification.id
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:show) }
    it { is_expected.not_to set_flash }
  end

  describe 'resend' do
    it 'resends the stolen notification' do
      Sidekiq::Worker.clear_all
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin)
      stolenNotification = FactoryGirl.create(:stolenNotification, sender: sender)
      # pp expect(EmailStolenNotificationWorker).to have_enqueued_job
      set_current_user(admin)
      expect do
        get :resend, id: stolenNotification.id
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end

    it 'redirects if the stolen notification has already been sent' do
      Sidekiq::Worker.clear_all
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin)
      stolenNotification = FactoryGirl.create(:stolenNotification, sender: sender)
      stolenNotification.update_attribute :send_dates, [69]
      set_current_user(admin)
      expect do
        get :resend, id: stolenNotification.id
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(0)
      expect(response).to redirect_to(:admin_stolenNotification)
    end

    it 'resends if the stolen notification has already been sent if we say pretty please' do
      Sidekiq::Worker.clear_all
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin)
      stolenNotification = FactoryGirl.create(:stolenNotification, sender: sender)
      stolenNotification.update_attribute :send_dates, [69]
      set_current_user(admin)
      expect do
        get :resend, id: stolenNotification.id, pretty_please: true
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end
  end
end
