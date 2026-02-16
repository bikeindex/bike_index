require "rails_helper"

RSpec.describe StravaSearchController, type: :request do
  describe "index" do
    context "when strava_search is built" do
      it "renders the SPA index.html" do
        build_path = Rails.root.join("public/strava_search/index.html")
        skip "StravaSearch not built (run BUILD_STRAVA_SEARCH=1 bin/setup)" unless File.exist?(build_path)

        get "/strava_search"
        expect(response.code).to eq("200")
        expect(response.body).to include("Strava Search")
      end
    end

    context "when strava_search is not built" do
      it "returns an error" do
        build_path = Rails.root.join("public/strava_search/index.html")
        skip "StravaSearch is built, skipping missing file test" if File.exist?(build_path)

        expect { get "/strava_search" }.to raise_error(ActionView::MissingTemplate)
      end
    end
  end
end
