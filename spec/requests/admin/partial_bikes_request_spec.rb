require "rails_helper"

RSpec.describe Admin::PartialBikesController, type: :request do
  base_url = "/admin/partial_bikes/"
  include_context :request_spec_logged_in_as_superuser
  let(:b_param) { FactoryBot.create(:user) }

  describe "index" do
    it "renders" do
      expect(b_param).to be_present
      get "#{base_url}?query=something"
      expect(response).to render_template :index
    end
  end
end
