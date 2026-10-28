# frozen_string_literal: true

module Pages
  module Admin
    module Recoveries
      module Table
        class Component < ApplicationComponent
          COLUMNS = {
            photo_cell: "Photo",
            recovered_at_cell: "Recovered",
            date_stolen_cell: "Stolen at",
            status_cell: "Status",
            bike_cell: "Bike",
            owner_cell: "Owner",
            theft_description_cell: "Theft info",
            story_cell: "Recovery story",
            quote_by_cell: "Display name",
            location_string_cell: "Display location",
            location_cell: "Location",
            helped_cell: "Helped",
            shareable_cell: "Shareable"
          }.freeze

          DEFAULT_COLUMNS = (COLUMNS.keys - %i[date_stolen_cell shareable_cell]).freeze

          def initialize(recoveries:, sort_state:)
            @recoveries = recoveries
            @sort_state = sort_state
          end

          private

          # A bike can be user hidden or deleted
          def rows
            bikes = Bike.unscoped.where(id: @recoveries.map(&:bike_id))
              .includes(current_ownership: {user: %i[membership_active email_bans_active]}).index_by(&:id)
            @recoveries.map { [it, bikes[it.bike_id]] }
          end

          # Only a recovery waiting on a decision can be displayed, so only those are editable
          def editable?(recovery) = recovery.waiting_on_decision?

          def display_defaults(recovery)
            RecoveryDisplay.attributes_from_stolen_record(recovery).slice(:quote, :quote_by, :location_string)
          end
        end
      end
    end
  end
end
