# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaSearchController, type: :request do
  describe "index" do
    it "renders the SPA inside the application layout with valid asset references" do
      get "/strava_search"
      expect(response.status).to eq(200)
      expect(response.body).to include('<div id="root">')
      expect(response.body).to include("index-yJzX-J6b.js")
      expect(response.body).to include("index-C-tmHfln.css")

      # Verify every referenced strava_search asset file exists
      response.body.scan(%r{(?:src|href)="(/strava_search/[^"]+)"}).flatten.each do |asset_path|
        file_path = Rails.root.join("public", asset_path.delete_prefix("/"))
        expect(File.exist?(file_path)).to eq(true), "Missing built asset: #{asset_path}"
      end
    end
  end
end
