# frozen_string_literal: true

module PageBlock::StravaIntegration
  class ComponentPreview < ApplicationComponentPreview
    def not_connected
      render(PageBlock::StravaIntegration::Component.new(user: user_without_strava))
    end

    def syncing
      render(PageBlock::StravaIntegration::Component.new(user: user_with_strava(:syncing)))
    end

    def synced
      render(PageBlock::StravaIntegration::Component.new(user: user_with_strava(:synced)))
    end

    def error
      render(PageBlock::StravaIntegration::Component.new(user: user_with_strava(:error)))
    end

    private

    def user_without_strava
      lookbook_user
    end

    def user_with_strava(status)
      user = lookbook_user
      si = user.strava_integration || user.build_strava_integration(
        access_token: "preview_token",
        refresh_token: "preview_refresh"
      )
      si.assign_attributes(
        status: status,
        athlete_activity_count: 150,
        activities_downloaded_count: (status == :syncing) ? 50 : 150,
        athlete_gear: [{"name" => "My Road Bike"}, {"name" => "My Mountain Bike"}]
      )
      user
    end
  end
end
