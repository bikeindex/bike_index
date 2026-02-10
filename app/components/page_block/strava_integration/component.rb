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

    def gear_list
      @strava_integration.strava_gears
    end

    def strava_icon(size, color: "#FC4C02")
      tag.svg(xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", width: size, height: size, style: "vertical-align: middle; display: inline-block;") do
        tag.path(d: "M15.387 17.944l-2.089-4.116h-3.065L15.387 24l5.15-10.172h-3.066m-7.008-5.599l2.836 5.598h4.172L10.463 0l-7 13.828h4.169", fill: color)
      end
    end
  end
end
