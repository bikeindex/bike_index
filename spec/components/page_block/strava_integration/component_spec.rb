# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::StravaIntegration::Component, type: :component do
  let(:instance) { described_class.new(user: user) }
  let(:component) { render_inline(instance) }
  let(:user) { FactoryBot.create(:user_confirmed) }

  context "not connected" do
    it "renders connect button" do
      expect(component).not_to have_text("Integration")
      expect(component).to have_text("Integrate your bikes with Strava")
      expect(component).to have_css("img[src*='btn_strava_connect']")
    end

    it "does not render disconnect button" do
      expect(component).not_to have_text("Disconnect Strava")
    end
  end

  context "connected - pending" do
    let!(:strava_integration) { FactoryBot.create(:strava_integration, user: user) }

    it "renders pending message" do
      expect(component).to have_text("Sync will begin shortly")
      expect(component).to have_text("Disconnect Strava")
    end
  end

  context "connected - syncing" do
    let!(:strava_integration) { FactoryBot.create(:strava_integration, :syncing, user: user) }

    it "renders progress bar and download count" do
      expect(component).to have_text("Syncing activities")
      expect(component).to have_css("#strava-download-count")
      expect(component).to have_text("Sync is running in the background")
    end

    it "renders stimulus controller for polling" do
      expect(component).to have_css("[data-controller='strava-sync-status']")
    end

    it "renders disconnect button" do
      expect(component).to have_text("Disconnect Strava")
    end
  end

  context "connected - synced" do
    let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced, user: user) }

    it "renders connected status and activity count" do
      expect(component).to have_text("Connected to Strava")
      expect(component).to have_text(/150\s+activities synced/)
    end

    context "with gear" do
      let!(:strava_gear) do
        FactoryBot.create(:strava_gear, strava_integration:,
          strava_gear_id: "b1234", strava_gear_name: "My Road Bike")
      end

      it "renders gear list" do
        expect(component).to have_text("Strava bikes connected")
      end
    end

    it "does not render gear section without gear" do
      expect(component).to have_text("Connected to Strava")
      expect(component).not_to have_text("Strava bikes connected")
    end

    it "renders disconnect button" do
      expect(component).to have_text("Disconnect Strava")
    end
  end

  context "connected - error" do
    let!(:strava_integration) { FactoryBot.create(:strava_integration, :error, user: user) }

    it "renders error message" do
      expect(component).to have_text("Sync error")
      expect(component).to have_text("disconnecting and reconnecting")
    end

    it "renders disconnect button" do
      expect(component).to have_text("Disconnect Strava")
    end
  end
end
