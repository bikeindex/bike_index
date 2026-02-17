# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaSearchController, type: :request do
  describe "index" do
    it "renders the SPA inside the application layout with valid asset references" do
      get "/strava_search"
      expect(response.status).to eq(200)
      expect(response.body).to include('<div id="root">')

      # Verify JS and CSS assets are referenced and exist on disk
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
