# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Wrapper
        class ComponentPreview < ApplicationComponentPreview
          # @display legacy_stylesheet true
          def default
            pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
            render Pages::Org::Search::Wrapper::Component.new(
              organization: lookbook_organization,
              pagy:,
              bikes:,
              per_page: 10,
              params: {},
              humanized_time_range: "in the past year"
            )
          end

          private

          def bikes
            return Bike.none if Rails.env.production? || lookbook_organization&.bikes.blank?

            lookbook_organization.bikes.limit(5)
          end
        end
      end
    end
  end
end
