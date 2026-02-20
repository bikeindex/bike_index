# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaSearchController, type: :request do
  let(:strava_app) { FactoryBot.create(:doorkeeper_app, is_internal: true) }

  before { stub_const("StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", strava_app.id.to_s) }

  describe "GET /strava_search" do
    it "redirects to login when not signed in" do
      get strava_search_path
      expect(response).to redirect_to(new_session_path)
    end

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "redirects to strava integration setup when user has no integration" do
        get strava_search_path
        expect(response).to redirect_to(new_strava_integration_path)
      end

      context "with strava integration" do
        let!(:strava_integration) { FactoryBot.create(:strava_integration, user: current_user, athlete_id: "12345") }

        it "renders with config and valid assets" do
          get strava_search_path
          expect(response.status).to eq 200
          expect(response.body).to include('<div id="root">')
          expect(response.body).to include("stravaSearchConfig")
          expect(response.body).to include('"athleteId":"12345"')

          asset_paths = response.body.scan(%r{(?:src|href)="(/strava_search/assets/[^"]+)"}).flatten
          expect(asset_paths.select { |p| p.end_with?(".js") }).to be_present
          expect(asset_paths.select { |p| p.end_with?(".css") }).to be_present
          asset_paths.each do |asset_path|
            file_path = Rails.root.join("public", asset_path.delete_prefix("/"))
            expect(File.exist?(file_path)).to eq(true), "Missing built asset: #{asset_path}"
          end
        end
      end
    end
  end

  describe "POST /strava_search/token" do
    it "returns 401 when not signed in" do
      post strava_search_token_path
      expect(response.status).to eq 401
      expect(json_result[:error]).to eq "Authentication required"
    end

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "returns 404 when user has no strava integration" do
        post strava_search_token_path
        expect(response.status).to eq 404
        expect(json_result[:error]).to eq "No Strava integration"
      end

      context "with strava integration" do
        let!(:strava_integration) { FactoryBot.create(:strava_integration, user: current_user, athlete_id: "12345") }

        it "returns existing valid token" do
          existing_token = Doorkeeper::AccessToken.create!(
            application_id: strava_app.id,
            resource_owner_id: current_user.id,
            scopes: "public",
            expires_in: Doorkeeper.configuration.access_token_expires_in
          )

          expect {
            post strava_search_token_path
          }.not_to change(Doorkeeper::AccessToken, :count)

          expect(response.status).to eq 200
          expect(json_result[:access_token]).to eq existing_token.token
          expect(json_result[:athlete_id]).to eq "12345"
        end

        it "creates a new token when no valid token exists" do
          expect {
            post strava_search_token_path
          }.to change(Doorkeeper::AccessToken, :count).by(1)

          expect(response.status).to eq 200
          expect(json_result[:access_token]).to be_present
          expect(json_result[:expires_in]).to be_present
          expect(json_result[:created_at]).to be_present
          expect(json_result[:athlete_id]).to eq "12345"

          token = Doorkeeper::AccessToken.last
          expect(token.resource_owner_id).to eq current_user.id
          expect(token.application_id).to eq strava_app.id
          expect(token.scopes.to_s).to eq "public"
        end

        it "returns JSON 422 when CSRF token is invalid" do
          allow_any_instance_of(StravaSearchController).to receive(:verified_request?).and_return(false)
          post strava_search_token_path
          expect(response.status).to eq 422
          expect(json_result[:error]).to eq "CSRF verification failed"
        end

        it "revokes expired token and creates a new one" do
          expired_token = Doorkeeper::AccessToken.create!(
            application_id: strava_app.id,
            resource_owner_id: current_user.id,
            scopes: "public",
            expires_in: 3600,
            created_at: 2.hours.ago
          )

          expect {
            post strava_search_token_path
          }.to change(Doorkeeper::AccessToken, :count).by(1)

          expect(response.status).to eq 200
          expect(json_result[:access_token]).to be_present
          expect(json_result[:access_token]).not_to eq expired_token.token
          expect(expired_token.reload.revoked?).to be true
        end
      end
    end
  end
end
