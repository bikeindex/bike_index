# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaIntegrationsController, type: :request do
  describe "new" do
    context "not logged in" do
      it "redirects to sign in" do
        get "/strava_integration/new"
        expect(response).to redirect_to(/session\/new/)
      end
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "redirects to Strava authorization with state and DEFAULT_SCOPE" do
        get "/strava_integration/new"
        expect(response).to redirect_to(/strava\.com\/oauth\/authorize/)
        location = response.location
        expect(location).to include("state=")
        scope_param = CGI.parse(URI.parse(location).query)["scope"].first
        expect(scope_param).to eq Integrations::StravaClient::DEFAULT_SCOPE
      end

      context "with strava_search scope" do
        it "redirects with STRAVA_SEARCH_SCOPE" do
          get "/strava_integration/new", params: {scope: "strava_search"}
          expect(response).to redirect_to(/strava\.com\/oauth\/authorize/)
          location = response.location
          expect(location).to include("state=")
          scope_param = CGI.parse(URI.parse(location).query)["scope"].first
          expect(scope_param).to eq Integrations::StravaClient::STRAVA_SEARCH_SCOPE
        end
      end
    end
  end

  describe "callback" do
    context "not logged in" do
      it "redirects to sign in" do
        get "/strava_integration/callback", params: {code: "test_code"}
        expect(response).to redirect_to(/session\/new/)
      end
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      # Initiate OAuth flow via `new` to set session state, return the state param
      def initiate_oauth_flow
        get "/strava_integration/new"
        CGI.parse(URI.parse(response.location).query)["state"].first
      end

      context "with error param" do
        it "redirects with error flash" do
          get "/strava_integration/callback", params: {error: "access_denied"}
          expect(response).to redirect_to(my_account_path)
          expect(flash[:error]).to match(/denied/)
        end
      end

      context "with missing state" do
        it "redirects with error flash" do
          initiate_oauth_flow
          get "/strava_integration/callback", params: {code: "test_auth_code"}
          expect(response).to redirect_to(my_account_path)
          expect(flash[:error]).to match(/invalid oauth state/i)
        end
      end

      context "with mismatched state" do
        it "redirects with error flash" do
          initiate_oauth_flow
          get "/strava_integration/callback", params: {code: "test_auth_code", state: "wrong"}
          expect(response).to redirect_to(my_account_path)
          expect(flash[:error]).to match(/invalid oauth state/i)
        end
      end

      context "with valid code and state" do
        it "creates strava integration and enqueues sync job" do
          oauth_state = initiate_oauth_flow
          VCR.use_cassette("strava-exchange_token") do
            expect {
              get "/strava_integration/callback",
                params: {code: "test_auth_code", state: oauth_state, scope: "read,activity:read_all,profile:read_all"}
            }.to change(StravaIntegration, :count).by(1)
              .and change(StravaJobs::FetchAthleteAndStats.jobs, :size).by(1)

            expect(response).to redirect_to(my_account_path)
            expect(flash[:success]).to match(/connected/i)

            strava_integration = current_user.reload.strava_integration
            expect(strava_integration.access_token).to be_present
            expect(strava_integration.refresh_token).to be_present
            expect(strava_integration.athlete_id).to eq("2430215")
            expect(strava_integration.status).to eq("pending")
            expect(strava_integration.strava_permissions).to eq Integrations::StravaClient::DEFAULT_SCOPE
          end
        end

        context "with strava_search scope" do
          it "redirects to strava_search" do
            oauth_state = initiate_oauth_flow
            VCR.use_cassette("strava-exchange_token") do
              get "/strava_integration/callback",
                params: {code: "test_auth_code", state: oauth_state, scope: Integrations::StravaClient::STRAVA_SEARCH_SCOPE}
              expect(response).to redirect_to(strava_search_path)
              expect(flash[:success]).to match(/connected/i)
              expect(current_user.reload.strava_integration.strava_permissions).to eq Integrations::StravaClient::STRAVA_SEARCH_SCOPE
            end
          end
        end

        context "user already has strava integration with same athlete" do
          let!(:existing) { FactoryBot.create(:strava_integration, user: current_user, athlete_id: "2430215") }

          it "updates existing integration without creating a new one" do
            oauth_state = initiate_oauth_flow
            VCR.use_cassette("strava-exchange_token") do
              expect {
                get "/strava_integration/callback",
                  params: {code: "test_auth_code", state: oauth_state, scope: Integrations::StravaClient::DEFAULT_SCOPE}
              }.to change(StravaIntegration, :count).by(0)
                .and change(StravaJobs::FetchAthleteAndStats.jobs, :size).by(0)

              expect(response).to redirect_to(my_account_path)
              expect(flash[:success]).to eq "Strava connected! Updating your activities."

              strava_integration = current_user.reload.strava_integration
              expect(strava_integration.id).to eq existing.id
              expect(strava_integration.access_token).to be_present
              expect(strava_integration.strava_permissions).to eq Integrations::StravaClient::DEFAULT_SCOPE
            end
          end
        end

        context "user already has strava integration with error status" do
          let!(:existing) { FactoryBot.create(:strava_integration, user: current_user, athlete_id: "2430215", status: :error) }

          it "destroys existing and creates new integration" do
            oauth_state = initiate_oauth_flow
            VCR.use_cassette("strava-exchange_token") do
              expect {
                get "/strava_integration/callback", params: {code: "test_auth_code", state: oauth_state}
              }.to change(StravaIntegration, :count).by(0)
                .and change(StravaIntegration.with_deleted, :count).by(1)
                .and change(StravaJobs::FetchAthleteAndStats.jobs, :size).by(1)

              existing.reload
              expect(existing.deleted_at).to be_present

              new_integration = current_user.reload.strava_integration
              expect(new_integration.id).not_to eq(existing.id)
              expect(flash[:success]).to match(/being synced/i)
            end
          end
        end

        context "user already has strava integration with different athlete" do
          let!(:existing) { FactoryBot.create(:strava_integration, user: current_user, athlete_id: "9999999") }

          it "destroys existing and creates new integration" do
            oauth_state = initiate_oauth_flow
            VCR.use_cassette("strava-exchange_token") do
              expect {
                get "/strava_integration/callback", params: {code: "test_auth_code", state: oauth_state}
              }.to change(StravaIntegration, :count).by(0)
                .and change(StravaIntegration.with_deleted, :count).by(1)
                .and change(StravaJobs::FetchAthleteAndStats.jobs, :size).by(1)

              existing.reload
              expect(existing.deleted_at).to be_present

              new_integration = current_user.reload.strava_integration
              expect(new_integration.id).not_to eq(existing.id)
              expect(new_integration.athlete_id).to eq("2430215")
            end
          end
        end
      end

      context "with invalid code" do
        it "redirects with error flash" do
          oauth_state = initiate_oauth_flow
          VCR.use_cassette("strava-exchange_token_failure") do
            get "/strava_integration/callback", params: {code: "bad_code", state: oauth_state}
            expect(response).to redirect_to(my_account_path)
            expect(flash[:error]).to match(/unable to connect/i)
          end
        end
      end
    end
  end

  describe "destroy" do
    context "not logged in" do
      it "redirects to sign in" do
        delete "/strava_integration"
        expect(response).to redirect_to(/session\/new/)
      end
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      context "with strava integration" do
        let!(:strava_integration) { FactoryBot.create(:strava_integration, user: current_user) }
        let!(:strava_activity) { FactoryBot.create(:strava_activity, strava_integration:) }

        it "destroys the integration and activities" do
          expect {
            delete "/strava_integration"
          }.to change(StravaIntegration, :count).by(-1)
            .and change(StravaActivity, :count).by(-1)

          expect(response).to redirect_to(my_account_path)
          expect(flash[:success]).to match(/removed/i)
        end
      end

      context "without strava integration" do
        it "redirects with error" do
          delete "/strava_integration"
          expect(response).to redirect_to(my_account_path)
          expect(flash[:error]).to match(/no strava/i)
        end
      end
    end
  end

  describe "sync_status" do
    context "not logged in" do
      it "redirects to sign in" do
        get "/strava_integration/sync_status"
        expect(response).to redirect_to(/session\/new/)
      end
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      context "with strava integration" do
        let!(:strava_integration) do
          FactoryBot.create(:strava_integration, :syncing, user: current_user)
        end

        it "returns JSON sync status" do
          get "/strava_integration/sync_status"
          expect(response.code).to eq("200")

          json = JSON.parse(response.body)
          expect(json["status"]).to eq("syncing")
          expect(json["activities_downloaded_count"]).to eq(50)
          expect(json["athlete_activity_count"]).to eq(150)
          expect(json["progress_percent"]).to eq(33)
        end
      end

      context "without strava integration" do
        it "redirects with error" do
          get "/strava_integration/sync_status"
          expect(response).to redirect_to(my_account_path)
        end
      end
    end
  end
end
