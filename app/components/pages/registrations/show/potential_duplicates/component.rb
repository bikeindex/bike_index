# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module PotentialDuplicates
        # Registrations sharing a serial segment with the bike, for law enforcement lookups
        class Component < ApplicationComponent
          LIMIT = 25
          # Out past UI::Card's p-4 to its border, which rounded-sm leaves 3px of radius inside
          TABLE_CLASSES = "tw:mt-3 tw:-mx-4 tw:overflow-hidden tw:border-gray-200 tw:dark:border-gray-700 " \
            "tw:not-last:border-b tw:last:-mb-4 tw:last:rounded-b-[3px]"

          # Inside an element with Pages::Org::Search::ColumnSettings' data attributes;
          # column_settings renders that element's panel and toggle
          def initialize(bike:, organization:, settings:, column_settings: false)
            @bike = bike
            @organization = organization
            @settings = settings
            @column_settings = column_settings
          end

          def render? = enabled? && duplicate_bikes_count.positive?

          def cache_version
            enabled? ? [duplicate_bikes.maximum(:updated_at), duplicate_bikes_count] : []
          end

          private

          def enabled? = @organization.enabled?("additional_registrations_information")

          def duplicate_bikes = @bike.duplicate_bikes

          def duplicate_bikes_count
            @duplicate_bikes_count ||= duplicate_bikes.count
          end

          def recent_duplicate_bikes = duplicate_bikes.reorder(id: :desc).limit(LIMIT)

          def more_duplicate_bikes? = duplicate_bikes_count > LIMIT

          def matching_segments
            @bike.normalized_serial_segments.considered_for_duplicate.pluck(:segment)
          end
        end
      end
    end
  end
end
