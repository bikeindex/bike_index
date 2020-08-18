require "rails_helper"

base_url = "/admin/parking_notifications"
RSpec.describe Admin::ParkingNotificationsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:parking_notification) { FactoryBot.create(:parking_notification_organized) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:parking_notifications)).to eq([parking_notification])
    end
  end
end
