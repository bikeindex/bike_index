require "rails_helper"

base_url = "/admin/customer_contacts"
RSpec.describe Admin::CustomerContactsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "show" do
    let(:customer_contact) { FactoryBot.create(:customer_contact) }

    it "renders" do
      get "#{base_url}/#{customer_contact.id}"
      expect(response.status).to eq 200
      expect(response.body).to include(edit_admin_bike_path(customer_contact.bike))
    end

    context "with the bike deleted" do
      it "renders the bike id" do
        customer_contact.bike.destroy
        get "#{base_url}/#{customer_contact.id}"
        expect(response.status).to eq 200
        expect(response.body).to include("Bike ID: #{customer_contact.bike_id}")
      end
    end
  end

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
      }.to change(EmailJobs::AdminContactStolenJob.jobs, :size).by(1)
      expect(response).to redirect_to edit_admin_stolen_bike_url(stolen_record.bike.id)
    end
  end
end
