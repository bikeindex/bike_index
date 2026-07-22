require "rails_helper"

RSpec.describe SuperuserRestriction, type: :request do
  describe "feature_flags" do
    context "not logged in" do
      it "returns 404" do
        get "/admin/feature_flags"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as regular user" do
      include_context :request_spec_logged_in_as_user
      it "returns 404" do
        get "/admin/feature_flags"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as developer (but not superuser)" do
      include_context :request_spec_logged_in_as_developer
      it "returns 404" do
        get "/admin/feature_flags"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as superuser" do
      include_context :request_spec_logged_in_as_superuser
      it "renders" do
        get "/admin/feature_flags"
        # Flipper UI redirects the mount root to /features
        expect(response.code).to eq("302")
      end
    end
  end
end
