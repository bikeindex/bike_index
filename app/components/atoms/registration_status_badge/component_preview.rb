# frozen_string_literal: true

module Atoms
  module RegistrationStatusBadge
    class ComponentPreview < ApplicationComponentPreview
      # Every status at once - hover or click a badge for the tooltip explaining it
      def all_statuses
        render_with_template(template: "atoms/registration_status_badge/preview/all_statuses",
          locals: {badges: status_bikes.values.map { {bike: it} }})
      end

      # With the time each status began, at ages the localized time formats differently
      def with_time
        times = [20.minutes.ago, 5.hours.ago, 2.days.ago, 3.weeks.ago, 5.months.ago, 14.months.ago, 3.years.ago]
        render_with_template(template: "atoms/registration_status_badge/preview/all_statuses",
          locals: {badges: status_bikes.values.zip(times).map { |bike, time| {bike:, time:} }})
      end

      # @param size select { choices: [xs, sm, md, lg, inherit] }
      def sizes(size: "lg")
        render(Atoms::RegistrationStatusBadge::Component.new(bike: status_bikes[:stolen], size: size&.to_sym))
      end

      private

      # Every status is reachable from an unsaved bike, so previews need no records
      def status_bikes
        {
          registered: ::Bike.new,
          for_sale: ::Bike.new(is_for_sale: true),
          stolen: ::Bike.new(status: :status_stolen),
          impounded: ::Bike.new(status: :status_impounded),
          found: found_bike,
          abandoned: ::Bike.new(status: :status_abandoned),
          unregistered: ::Bike.new(status: :unregistered_parking_notification)
        }
      end

      # An impound record with no organization is someone finding it, not impounding it
      def found_bike
        ::Bike.new(status: :status_impounded).tap { it.impound_records.build }
      end
    end
  end
end
