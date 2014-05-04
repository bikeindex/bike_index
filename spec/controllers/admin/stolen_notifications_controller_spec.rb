require 'spec_helper'

describe Admin::StolenNotificationsController do
  
  describe :resend do 
    it 'should resend the stolen notification' do
      sender = FactoryGirl.create(:user, can_send_many_stolen_notifications: true)
      admin = FactoryGirl.create(:user, superuser: true)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: sender)
      StolenNotificationEmailJob.should have_queued(stolen_notification.id)
      set_current_user(admin)
      get :resend, id: stolen_notification.id
      StolenNotificationEmailJob.should have_queue_size_of(2)
    end
  end

end
