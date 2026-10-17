# frozen_string_literal: true

module Pages
  module Org
    module ParkingNotifications
      module Index
        # The org-parking-notifications-index Stimulus controller maps the loaded
        # notifications with MapLibre and narrows the table to the ones in view
        class Component < ApplicationComponent
          STATUS_DISPLAY = {
            current: {m: "Current notifications"},
            resolved: {m: "Resolved notifications", s: "retrieved, impounded or otherwise resolved"},
            all: {m: "All statuses"},
            retrieved: {m: "Retrieved notifications", s: "notifications marked retrieved"},
            replaced: {m: "Replaced notifications", s: "notifications replaced by another notification"},
            impounded: {m: "Impounded notifications", s: "impound notifications"},
            impounded_resolved: {m: "Impounded resolved", s: "impounded bikes which have been resolved"}
          }.freeze

          UNREGISTERED_DISPLAY = {
            "all" => "All bikes",
            "only_unregistered" => "Only unregistered bikes",
            "not_unregistered" => "Registered bikes only"
          }.freeze

          def initialize(organization:, parking_notifications:, total_count:, per_page:, sort_state:,
            interpreted_params:, search_kind:, search_status:, search_unregistered:, unpermitted_statuses:,
            period:, start_time:, end_time:, search_bounding_box: nil, map_place: nil, map_location: nil,
            search_bike_id: nil, filtered_user_id: nil, filtered_user: nil,
            notifications_failed_resolved: nil, repeated_kind: nil)
            @organization = organization
            @parking_notifications = parking_notifications
            @total_count = total_count
            @per_page = per_page
            @sort_state = sort_state
            @interpreted_params = interpreted_params
            @search_kind = search_kind
            @search_status = search_status
            @search_unregistered = search_unregistered
            @unpermitted_statuses = unpermitted_statuses
            @period = period
            @start_time = start_time
            @end_time = end_time
            @search_bounding_box = search_bounding_box
            @map_place = map_place
            @map_location = map_location
            @search_bike_id = search_bike_id
            @filtered_user_id = filtered_user_id
            @filtered_user = filtered_user
            @notifications_failed_resolved = notifications_failed_resolved
            @repeated_kind = repeated_kind
          end

          private

          def controller_data
            focus = @organization.map_focus_coordinates
            {
              controller: "org--parking-notifications-index",
              action: "keydown.esc@window->org--parking-notifications-index#closePopup",
              "org--parking-notifications-index-latitude-value": focus[:latitude],
              "org--parking-notifications-index-longitude-value": focus[:longitude],
              "org--parking-notifications-index-bounding-box-value": @search_bounding_box.to_a.to_json,
              "org--parking-notifications-index-place-value": @map_place.to_a.to_json
            }
          end

          def search_params = @sort_state.search_params

          def index_path(**changes)
            organization_parking_notifications_path({**search_params, **changes, organization_id: @organization.to_param})
          end

          # An entry that's already applied links to clearing it
          def toggle_path(key, value, current)
            index_path(key => ((current == value.to_s) ? nil : value))
          end

          def kind_display(kind)
            (kind == "all") ? "All types" : "#{kind.humanize}s"
          end

          def status_display_hash
            STATUS_DISPLAY.except(*@unpermitted_statuses.map(&:to_sym))
          end

          # Fallback to status, in case there isn't a match (only happens if manually writing in other statuses right now)
          def current_status
            status_display_hash[@search_status.to_sym] || {m: @search_status}
          end

          # Every notification on this view is current and unresolved, so both columns are noise
          def viewing_current? = @search_status == "current"

          def searched_bike
            @searched_bike ||= Bike.unscoped.find_by_id(@search_bike_id)
          end
        end
      end
    end
  end
end
