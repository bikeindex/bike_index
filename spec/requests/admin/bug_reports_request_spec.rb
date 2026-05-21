require "rails_helper"

base_url = "/admin/bug_reports"
RSpec.describe Admin::BugReportsController, type: :request do
  let(:subject) { FactoryBot.create(:bug_report) }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{subject.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end
end
