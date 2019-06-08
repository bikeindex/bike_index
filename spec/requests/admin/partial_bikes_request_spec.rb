require "rails_helper"

RSpec.describe Admin::PartialBikesController, type: :request do
  base_url = "/admin/partial_bikes/"

  # Request specs don't have cookies so we need to stub stuff if we're in request specs
  # This is suboptimal, but hey, it gets us to request specs for now
  before { allow(User).to receive(:from_auth) { user } }
  let(:user) { FactoryBot.create(:admin) }
  let(:b_param) { FactoryBot.create(:user) }

  describe "index" do
    it "renders" do
      expect(b_param).to be_present
      get "#{base_url}?query=something"
      expect(response).to render_template :index
    end
  end
end
