require "rails_helper"

base_url = "/memberships"
RSpec.describe MembershipsController, type: :request do
  let(:re_record_interval) { 30.days }

  describe "new" do
    context "user not logged in" do
      it "redirects" do
        get "#{base_url}/new"
        expect(response).to redirect_to(/users\/new/) # weird subdomain issue matching url directly otherwise
      end
    end
    context "with user" do
      include_context :request_spec_logged_in_as_user
      it "renders" do
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
      end
    end
  end
end
