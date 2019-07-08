require "rails_helper"

RSpec.describe Admin::MembershipsController, type: :request do
  base_url = "/admin/memberships/"

  include_context :request_spec_logged_in_as_superuser
  let(:organization_invitation) { FactoryBot.create(:organization_invitation) }

  describe "index" do
    it "renders" do
      expect(organization_invitation).to be_present
      get base_url
      expect(response).to render_template :index
    end
  end
end
