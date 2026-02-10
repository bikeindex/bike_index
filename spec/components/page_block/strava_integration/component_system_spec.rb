# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::StravaIntegration::Component, type: :system do
  let(:preview_path) { "/rails/view_components/page_block/strava_integration/component/#{preview}" }

  context "not_connected" do
    let(:preview) { "not_connected" }

    it "renders connect button" do
      visit(preview_path)
      expect(page).to have_content "Strava Integration"
      expect(page).to have_content "Integrate your bikes with Strava"
      expect(page).to have_link "Connect with Strava"
    end
  end

  context "syncing" do
    let(:preview) { "syncing" }

    it "renders syncing progress" do
      visit(preview_path)
      expect(page).to have_content "Syncing activities..."
      expect(page).to have_content "50 / 150"
      expect(page).to have_content "downloaded"
    end
  end

  context "synced" do
    let(:preview) { "synced" }

    it "renders synced state with gear" do
      visit(preview_path)
      expect(page).to have_content "Connected to Strava"
      expect(page).to have_content "150 activities synced"
      expect(page).to have_content "Strava bikes connected"
      expect(page).to have_link "Disconnect Strava"
    end
  end

  context "error" do
    let(:preview) { "error" }

    it "renders error state" do
      visit(preview_path)
      expect(page).to have_content "Sync error"
      expect(page).to have_content "There was an error syncing your Strava activities"
      expect(page).to have_link "Disconnect Strava"
    end
  end
end
