# frozen_string_literal: true

module PageBlock::StravaIntegration
  class ComponentPreview < ApplicationComponentPreview
    # @group Status Variants
    # @display legacy_stylesheet true
    def not_connected
      render(Component.new(user: built_user))
    end

    # @display legacy_stylesheet true
    def syncing
      render(Component.new(user: user_with_strava(:syncing)))
    end

    # @display legacy_stylesheet true
    def synced
      render(Component.new(user: user_with_strava(:synced)))
    end

    # @display legacy_stylesheet true
    def error
      render(Component.new(user: user_with_strava(:error)))
    end
    # @endgroup

    private

    def built_user
      User.new(name: "Preview User", email: "preview@example.com")
    end

    def user_with_strava(status)
      user = built_user
      strava_integration = user.build_strava_integration(
        access_token: "preview_token",
        refresh_token: "preview_refresh",
        status:,
        athlete_activity_count: 150,
        activities_downloaded_count: (status == :syncing) ? 50 : 150
      )
      strava_integration.strava_gears.build(strava_gear_id: "b1", strava_gear_name: "My Road Bike", gear_type: "bike")
      strava_integration.strava_gears.build(strava_gear_id: "b2", strava_gear_name: "My Mountain Bike", gear_type: "bike")
      user
    end
  end
end
