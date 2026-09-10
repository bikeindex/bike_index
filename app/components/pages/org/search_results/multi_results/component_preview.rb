# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module MultiResults
        class ComponentPreview < ApplicationComponentPreview
          # @display legacy_stylesheet true
          def default
            pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
            render Component.new(
              organization: lookbook_organization,
              query: "SERIAL111",
              chip_id: "chip_0",
              pagy:,
              bikes:
            )
          end

          # @display legacy_stylesheet true
          def close_serials
            pagy = Pagy::Offset.new(count: 0, page: 1, limit: 10)
            render Component.new(
              organization: lookbook_organization,
              query: "SERIAL111",
              chip_id: "chip_0",
              pagy:,
              bikes: Bike.none,
              close_serials: close_serial_bikes
            )
          end

          private

          def bikes
            return Bike.none if Rails.env.production? || lookbook_organization&.bikes.blank?

            lookbook_organization.bikes.limit(5)
          end

          def close_serial_bikes
            return Bike.none if Rails.env.production? || lookbook_organization&.bikes.blank?

            lookbook_organization.bikes.limit(3)
          end
        end
      end
    end
  end
end
