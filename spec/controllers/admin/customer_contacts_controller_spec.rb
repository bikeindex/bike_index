require 'spec_helper'

describe Admin::CustomerContactsController do
  describe 'create' do
    it 'creates the contact, send the email and redirect to the bike' do
      stolen_record = FactoryBot.create(:stolen_record)
      # pp stolen_record.bike.id
      user = FactoryBot.create(:admin)
      customer_contact = {
        user_email: stolen_record.bike.owner_email,
        creator_email: user.email,
        bike_id: stolen_record.bike.id,
        title: 'some title',
        body: 'some message',
        contact_type: 'stolen_contact' }
      set_current_user(user)
      expect do
        post :create, customer_contact: customer_contact
      end.to change(EmailAdminContactStolenWorker.jobs, :size).by(1)
      expect(response).to redirect_to edit_admin_stolen_bike_url(stolen_record.bike.id)
    end
  end
end
