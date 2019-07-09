require "rails_helper"

RSpec.describe Admin::MembershipsController, type: :request do
  base_url = "/admin/memberships/"

  include_context :request_spec_logged_in_as_superuser
  let(:membership) { FactoryBot.create(:membership) }

  describe "index" do
    it "renders" do
      expect(membership).to be_present
      get base_url
      expect(response).to render_template :index
    end
  end
end
