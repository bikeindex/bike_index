# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaSearchController, type: :request do
  describe "index" do
    it "renders the built SPA with valid asset references" do
      get "/strava_search"
      expect(response.status).to eq(200)
      expect(response.body).to include("<title>Strava Search</title>")
      expect(response.body).to include('<div id="root">')

      # Verify every referenced asset file exists in public/strava_search/
      response.body.scan(%r{(?:src|href)="(/strava_search/[^"]+)"}).flatten.each do |asset_path|
        file_path = Rails.root.join("public", asset_path.delete_prefix("/"))
        expect(File.exist?(file_path)).to eq(true), "Missing built asset: #{asset_path}"
      end
    end
  end
end
