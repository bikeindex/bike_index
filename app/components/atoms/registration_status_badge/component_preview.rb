# frozen_string_literal: true

module Atoms
  module RegistrationStatusBadge
    class ComponentPreview < ApplicationComponentPreview
      # Every status at once - hover or click a badge for the tooltip explaining it
      def all_statuses
        render_with_template(template: "atoms/registration_status_badge/preview/all_statuses",
          locals: {bikes: status_bikes.values})
      end

      # @param size select { choices: [xs, sm, md, lg] }
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
