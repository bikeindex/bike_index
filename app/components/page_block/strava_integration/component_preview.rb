# frozen_string_literal: true

module PageBlock::StravaIntegration
  class ComponentPreview < ApplicationComponentPreview
    def not_connected
      render(Component.new(user: built_user))
    end

    def syncing
      render(Component.new(user: user_with_strava(:syncing)))
    end

    def synced
      render(Component.new(user: user_with_strava(:synced)))
    end

    def error
      render(Component.new(user: user_with_strava(:error)))
    end

    private

    def built_user
      User.new(name: "Preview User", email: "preview@example.com")
    end

    def user_with_strava(status)
      user = built_user
      integration = user.build_strava_integration(
        access_token: "preview_token",
        refresh_token: "preview_refresh"
      )
      integration.assign_attributes(
        status:,
        athlete_activity_count: 150,
        activities_downloaded_count: (status == :syncing) ? 50 : 150,
        athlete_gear: [{"name" => "My Road Bike"}, {"name" => "My Mountain Bike"}]
      )
      user
    end
  end
end
