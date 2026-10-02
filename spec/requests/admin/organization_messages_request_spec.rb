require "rails_helper"

base_url = "/admin/organization_messages"
RSpec.describe Admin::OrganizationMessagesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:organization_message) { FactoryBot.create(:organization_message, message: "Your lock is on the rack") }
  let!(:organization_message2) { FactoryBot.create(:organization_message) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to match_array([organization_message.id, organization_message2.id])
      expect(response.body).to include("Your lock is on the rack")

      get base_url, params: {search_bike_id: organization_message.bike_id}
      expect(assigns(:collection).pluck(:id)).to eq([organization_message.id])

      get base_url, params: {organization_id: organization_message2.organization_id}
      expect(assigns(:collection).pluck(:id)).to eq([organization_message2.id])

      get base_url, params: {user_id: organization_message.sender_id}
      expect(assigns(:collection).pluck(:id)).to eq([organization_message.id])

      get base_url, params: {search_email: organization_message2.receiver_email}
      expect(assigns(:collection).pluck(:id)).to eq([organization_message2.id])
    end
  end
end
