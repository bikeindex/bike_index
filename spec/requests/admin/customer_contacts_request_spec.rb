require "rails_helper"

base_url = "/admin/customer_contacts"
RSpec.describe Admin::CustomerContactsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "create" do
    it "creates the contact, send the email and redirect to the bike" do
      stolen_record = FactoryBot.create(:stolen_record)
      # pp stolen_record.bike.id
      customer_contact = {
        user_email: stolen_record.bike.owner_email,
        creator_email: current_user.email,
        bike_id: stolen_record.bike.id,
        title: "some title",
        body: "some message",
        kind: :stolen_contact
      }
      expect {
        post base_url, params: {customer_contact: customer_contact}
      }.to change(EmailAdminContactStolenJob.jobs, :size).by(1)
      expect(response).to redirect_to edit_admin_stolen_bike_url(stolen_record.bike.id)
    end
  end
end
