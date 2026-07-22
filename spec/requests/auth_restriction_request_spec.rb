require "rails_helper"

RSpec.describe AuthRestriction, type: :request do
  describe AuthRestriction::Developer do
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

  describe AuthRestriction::Superuser do
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
end
