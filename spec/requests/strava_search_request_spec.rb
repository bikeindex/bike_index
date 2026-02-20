# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaSearchController, type: :request do
  describe "GET /strava_search" do
    it "redirects to login when not signed in" do
      get strava_search_path
      expect(response).to redirect_to(new_session_path)
    end

    context "signed in" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      before { log_in(user) }

      it "redirects to strava integration setup when user has no integration" do
        get strava_search_path
        expect(response).to redirect_to(new_strava_integration_path)
      end

      context "with strava integration" do
        let!(:strava_integration) { FactoryBot.create(:strava_integration, user:, athlete_id: "12345") }

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
      let(:user) { FactoryBot.create(:user_confirmed) }
      before { log_in(user) }

      it "returns 404 when user has no strava integration" do
        post strava_search_token_path
        expect(response.status).to eq 404
        expect(json_result[:error]).to eq "No Strava integration"
      end

      context "with strava integration" do
        let!(:strava_integration) { FactoryBot.create(:strava_integration, user:, athlete_id: "12345") }

        it "creates a doorkeeper token and returns it" do
          expect {
            post strava_search_token_path
          }.to change(Doorkeeper::AccessToken, :count).by(1)

          expect(response.status).to eq 200
          expect(json_result[:access_token]).to be_present
          expect(json_result[:expires_in]).to be_present
          expect(json_result[:created_at]).to be_present
          expect(json_result[:athlete_id]).to eq "12345"

          token = Doorkeeper::AccessToken.last
          expect(token.resource_owner_id).to eq user.id
          expect(token.application_id.to_s).to eq StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID.to_s
          expect(token.scopes.to_s).to eq "public"
        end

        it "creates a new token each time" do
          post strava_search_token_path
          first_token = json_result[:access_token]
          post strava_search_token_path
          second_token = json_result[:access_token]
          expect(first_token).to_not eq second_token
        end
      end
    end
  end
end
