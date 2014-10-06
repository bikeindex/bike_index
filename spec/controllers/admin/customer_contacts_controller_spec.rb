require 'spec_helper'

describe Admin::CustomerContactsController do

  describe :create do 
    xit "should create the contact, send the email and redirect to the bike" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      user = FactoryGirl.create(:user, superuser: true)
      customer_contact = CustomerContact.new(user_email: stolen_record.bike.owner_email, creator_email: user.email, title: 'some title')
      customer_contact.body = 'some message'
      customer_contact.contact_type = 'stolen_contact'
      customer_contact.bike_id = stolen_record.bike.id
      set_current_user(user)
      Resque.should_receive(:enqueue).with(AdminContactStolenEmailJob, 1)
      post :create, {customer_contact: customer_contact}
      response.should redirect_to edit_admin_stolen_bike_url(stolen_record.bike)
    end
  end

end
