require "rails_helper"

RSpec.describe Admin::ExportsController, type: :request do
  base_url = "/admin/exports"

  # Request specs don't have cookies so we need to stub stuff if we're in request specs
  # This is suboptimal, but hey, it gets us to request specs for now
  before { allow(User).to receive(:from_auth) { user } }
  let(:user) { FactoryBot.create(:admin) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
