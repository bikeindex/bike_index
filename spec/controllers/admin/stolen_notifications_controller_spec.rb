require 'spec_helper'

describe Admin::StolenNotificationsController do
  describe :index do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
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
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      get :show, id: stolen_notification.id 
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
    it { should_not set_the_flash }
  end
  
  describe :resend do 
    it 'should resend the stolen notification' do
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:user, superuser: true)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      ResqueSpec.reset!
      # pp StolenNotificationEmailJob.peek
      set_current_user(admin)
      get :resend, id: stolen_notification.id
      StolenNotificationEmailJob.should have_queue_size_of(1)
    end

    it 'should redirect if the stolen notification has already been sent' do
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:user, superuser: true)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      ResqueSpec.reset!
      stolen_notification.update_attribute :send_dates, [69]
      set_current_user(admin)
      get :resend, id: stolen_notification.id
      response.should redirect_to(:admin_stolen_notification)
      StolenNotificationEmailJob.should have_queue_size_of(0)
    end

    it 'should resend if the stolen notification has already been sent if we say pretty please' do
      sender = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:user, superuser: true)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      ResqueSpec.reset!
      stolen_notification.update_attribute :send_dates, [69]
      set_current_user(admin)
      get :resend, {id: stolen_notification.id, pretty_please: true}
      StolenNotificationEmailJob.should have_queue_size_of(1)
    end
  end

end
