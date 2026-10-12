# frozen_string_literal: true

module Pages
  module Admin
    module StolenBikes
      module Table
        # The admin stolen bikes index: a card of stolen records with a column picker, and the
        # approve, spam and delete actions for the checked rows above and below the table
        class Component < ApplicationComponent
          COLUMNS = {
            photo_cell: "Photo",
            created_at_cell: "Stolen created",
            date_stolen_cell: "Stolen at",
            bike_cell: "Bike",
            value_cell: "Value",
            theft_description_cell: "Theft info",
            location_cell: "Location",
            duplicates_cell: "Duplicates",
            owner_cell: "Owner",
            approved_cell: "Approved"
          }.freeze

          DEFAULT_COLUMNS = (COLUMNS.keys - %i[value_cell]).map(&:to_s).freeze

          # What Pages::Org::Search::ColumnSettings reads its checkboxes from
          ColumnSettings = Data.define(:panel_columns, :panel_labels, :initially_checked_columns) do
            def always_visible?(_cell_name) = false
          end

          def initialize(stolen_records:, pagy:, sort_state:)
            @stolen_records = stolen_records
            @pagy = pagy
            @sort_state = sort_state
          end

          private

          # A bike can be user hidden or deleted
          def rows
            bikes = Bike.unscoped.where(id: @stolen_records.map(&:bike_id)).index_by(&:id)
            @stolen_records.map { [it, bikes[it.bike_id]] }
          end

          def duplicate_counts
            NormalizedSerialSegment.where(bike_id: @stolen_records.map(&:bike_id),
              duplicate_bike_group_id: DuplicateBikeGroup.unignored.select(:id)).group(:bike_id).count
          end

          def column_settings
            ColumnSettings.new(panel_columns: COLUMNS.keys.map(&:to_s), panel_labels: COLUMNS,
              initially_checked_columns: DEFAULT_COLUMNS)
          end

          def card_data_attributes
            {controller: "table-multi-checkbox ui--collapse org--search-column-settings",
             "ui--collapse-storage-key-value": "adminStolenBikesColumnsOpen",
             "org--search-column-settings-storage-key-value": "adminStolenBikesColumns"}
          end

          def location(stolen_record)
            place = [stolen_record.city, stolen_record.region, stolen_record.postal_code].compact_blank.first
            country = stolen_record.country
            [place, (country.iso if country.present? && !country.united_states?)].compact.join(", ")
          end
        end
      end
    end
  end
end
