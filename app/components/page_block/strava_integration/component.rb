# frozen_string_literal: true

module PageBlock::StravaIntegration
  class Component < ApplicationComponent
    def initialize(user:)
      @user = user
      @strava_integration = user.strava_integration
    end

    private

    def connected?
      @strava_integration.present?
    end

    def syncing?
      connected? && @strava_integration.syncing?
    end

    def synced?
      connected? && @strava_integration.synced?
    end

    def error?
      connected? && @strava_integration.error?
    end

    def pending?
      connected? && @strava_integration.pending?
    end

    def progress_percent
      @strava_integration.sync_progress_percent
    end

    def downloaded_count
      @strava_integration.activities_downloaded_count
    end

    def total_count
      @strava_integration.athlete_activity_count || "?"
    end

    def strava_icon
      helpers.inline_svg_tag("logos/strava.svg", title: "Strava", style: "vertical-align: baseline; display: inline-block; height: 12px; width: auto;")
    end
  end
end
