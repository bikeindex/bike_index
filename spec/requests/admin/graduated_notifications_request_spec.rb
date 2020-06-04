require "rails_helper"

base_url = "/admin/graduated_notifications"
RSpec.describe Admin::GraduatedNotificationsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:graduated_notification) { FactoryBot.create(:graduated_notification) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:graduated_notifications)).to eq([graduated_notification])
    end
  end
end
