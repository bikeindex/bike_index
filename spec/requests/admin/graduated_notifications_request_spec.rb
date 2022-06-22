require "rails_helper"

base_url = "/admin/graduated_notifications"
RSpec.describe Admin::GraduatedNotificationsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:graduated_notification) { FactoryBot.create(:graduated_notification) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:graduated_notifications)).to eq([])

      expect(graduated_notification).to be_present
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:graduated_notifications)).to eq([graduated_notification])
    end
  end
end
