require 'spec_helper'

describe Admin::StolenNotificationsController do
  describe :index do 
    before do 
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should_not set_the_flash }
  end

  describe :show do 
    before do 
      stolen_notification = FactoryGirl.create(:stolen_notification)
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :show, id: stolen_notification.id 
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
    it { should_not set_the_flash }
  end
  
  describe :resend do 
    it 'resends the stolen notification' do
      Sidekiq::Worker.clear_all
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      # pp expect(EmailStolenNotificationWorker).to have_enqueued_job
      set_current_user(admin)
      expect {
        get :resend, id: stolen_notification.id
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end

    it 'redirects if the stolen notification has already been sent' do
      Sidekiq::Worker.clear_all
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      stolen_notification.update_attribute :send_dates, [69]
      set_current_user(admin)
      expect {
        get :resend, id: stolen_notification.id
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(0)
      response.should redirect_to(:admin_stolen_notification)
    end

    it 'resends if the stolen notification has already been sent if we say pretty please' do
      Sidekiq::Worker.clear_all
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      stolen_notification.update_attribute :send_dates, [69]
      set_current_user(admin)
      expect {
      get :resend, {id: stolen_notification.id, pretty_please: true}
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end
  end

end
