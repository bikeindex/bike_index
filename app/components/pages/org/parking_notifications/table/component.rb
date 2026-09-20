# frozen_string_literal: true

module Pages
  module Org
    module ParkingNotifications
      module Table
        class Component < ApplicationComponent
          def initialize(parking_notifications:, current_organization:, sort_state: ComponentStructs::SortState.new,
            render_sortable: false, map_rows: false, render_address: false, render_multiselect: false,
            skip_bike: false, skip_status: false, skip_resolved: false)
            @parking_notifications = parking_notifications
            @current_organization = current_organization
            @sort_state = sort_state
            @render_sortable = render_sortable
            @map_rows = map_rows
            @render_address = render_address
            @render_multiselect = render_multiselect
            @skip_bike = skip_bike
            @skip_status = skip_status
            @skip_resolved = skip_resolved
          end

          private

          # The index's map controller pins each row and narrows the table to what's in view
          def row_data
            return nil unless @map_rows

            ->(parking_notification) {
              {"org--parking-notifications-index-target": "row",
               latitude: parking_notification.latitude, longitude: parking_notification.longitude}
            }
          end

          def table_data
            {"org--parking-notifications-index-target": "table"} if @map_rows
          end

          # The localizer writes the viewer's zone into the empty small
          def created_label
            safe_join([translation(".created"), " ", tag.small(class: "localizeTimezone")])
          end

          def message_notes(parking_notification)
            safe_join([["Notes", parking_notification.internal_notes], ["Message", parking_notification.message]]
              .filter_map { |label, text| safe_join([tag.strong("#{label}:"), " ", text]) if text.present? }, tag.br)
          end
        end
      end
    end
  end
end
