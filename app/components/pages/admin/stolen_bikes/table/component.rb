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

          # Once the card is full bleed: out past the admin layout's gutter to the page's edges
          TABLE_BLEED_CLASSES = "tw:@max-[672px]/twwiderow:mx-[calc(var(--gutter)*-1)]"

          def initialize(stolen_records:, index:)
            @stolen_records = stolen_records
            @index = index
            @pagy = index.pagy
            @sort_state = index.sort_state
          end

          private

          def show_time_range? = @index.time_range.present? && @index.period != "all"

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
