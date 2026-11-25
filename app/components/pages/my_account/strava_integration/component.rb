# frozen_string_literal: true

module Pages
  module MyAccount
    module StravaIntegration
      class Component < ApplicationComponent
        # link_bikes_path: where a bike is linked to its Strava gear, which is per bike
        def initialize(user:, link_bikes_path: nil)
          @strava_integration = user.strava_integration
          @link_bikes_path = link_bikes_path
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

        def in_progress? = syncing? || pending?

        def progress_percent
          @strava_integration.sync_progress_percent
        end

        def downloaded_count
          @strava_integration.activities_downloaded_count
        end

        def total_count
          @strava_integration.athlete_activity_count || "?"
        end

        # In memory, so the previews' unsaved gears count too
        def strava_bikes
          @strava_integration.strava_gears.select(&:bike?)
        end

        def link_bikes?
          @link_bikes_path.present? && @strava_integration.show_gear_link?
        end
      end
    end
  end
end
