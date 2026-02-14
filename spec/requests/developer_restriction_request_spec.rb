require "rails_helper"

RSpec.describe DeveloperRestriction, type: :request do
  describe "sidekiq" do
    context "not logged in" do
      it "returns 404" do
        get "/sidekiq"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as regular user" do
      include_context :request_spec_logged_in_as_user
      it "returns 404" do
        get "/sidekiq"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as superuser (but not developer)" do
      let(:current_user) { FactoryBot.create(:superuser, developer: false) }
      before { log_in(current_user) }
      it "returns 404" do
        get "/sidekiq"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as developer" do
      include_context :request_spec_logged_in_as_developer
      it "renders" do
        get "/sidekiq"
        expect(response.code).to eq("200")
      end
    end
  end

  describe "pghero" do
    context "not logged in" do
      it "returns 404" do
        get "/pghero"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as regular user" do
      include_context :request_spec_logged_in_as_user
      it "returns 404" do
        get "/pghero"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as superuser (but not developer)" do
      let(:current_user) { FactoryBot.create(:superuser, developer: false) }
      before { log_in(current_user) }
      it "returns 404" do
        get "/pghero"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as developer" do
      include_context :request_spec_logged_in_as_developer
      it "renders" do
        get "/pghero"
        # pghero redirects to a specific database endpoint
        expect(response.code).to eq("302")
      end
    end
  end
end
