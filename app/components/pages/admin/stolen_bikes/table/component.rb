# frozen_string_literal: true

module Pages
  module Admin
    module StolenBikes
      module Table
        class Component < ApplicationComponent
          COLUMNS = {
            photo_cell: "Photo",
            created_at_cell: "Stolen created",
            date_stolen_cell: "Stolen at",
            bike_cell: "Bike",
            value_cell: "Value",
            theft_description_cell: "Theft info",
            location_cell: "Location",
            police_department_cell: "Police department",
            police_report_cell: "Police report",
            duplicates_cell: "Duplicates",
            owner_cell: "Owner",
            approved_cell: "Approved"
          }.freeze

          DEFAULT_COLUMNS = (COLUMNS.keys - %i[value_cell police_department_cell police_report_cell]).freeze

          def initialize(stolen_records:, sort_state:)
            @stolen_records = stolen_records
            @sort_state = sort_state
          end

          private

          # A bike can be user hidden or deleted
          def rows
            bikes = Bike.unscoped.where(id: @stolen_records.map(&:bike_id))
              .includes(current_ownership: {user: %i[membership_active email_bans_active]}).index_by(&:id)
            @stolen_records.map { [it, bikes[it.bike_id]] }
          end

          def duplicate_counts
            NormalizedSerialSegment.where(bike_id: @stolen_records.map(&:bike_id),
              duplicate_bike_group_id: DuplicateBikeGroup.unignored.select(:id)).group(:bike_id).count
          end

          def card_data_attributes
            column_settings = UI::ColumnSettings::Component.data_attributes(storage_key: "adminStolenBikesColumns",
              narrow_hidden_columns: %w[photo_cell created_at_cell])
            column_settings.merge(controller: "table-multi-checkbox ui--table-column-order #{column_settings[:controller]}",
              "ui--table-column-order-storage-key-value": "adminStolenBikesColumnOrder")
          end

          def location(stolen_record)
            place = [stolen_record.city, stolen_record.region, stolen_record.postal_code].compact_blank.first
            iso = stolen_record.country_iso
            [place, (iso unless iso == "US")].compact.join(", ")
          end
        end
      end
    end
  end
end
