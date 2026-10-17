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

          def message_notes(parking_notification)
            safe_join([["Notes", parking_notification.internal_notes], ["Message", parking_notification.message]]
              .filter_map { |label, text| safe_join([tag.strong("#{label}:"), " ", text]) if text.present? }, tag.br)
          end
        end
      end
    end
  end
end
