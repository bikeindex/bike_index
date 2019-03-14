require "spec_helper"

base_url = "/admin/exports"
describe "Admin::ExportsController" do
  # Request specs don't have cookies so we need to stub stuff if we're in request specs
  # This is suboptimal, but hey, it gets us to request specs for now
  before { allow(User).to receive(:from_auth) { user } }

  describe "index" do
    let(:user) { FactoryBot.create(:admin) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
