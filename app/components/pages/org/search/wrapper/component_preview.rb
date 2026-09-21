# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Wrapper
        class ComponentPreview < ApplicationComponentPreview
          # @display legacy_stylesheet true
          def default
            render Pages::Org::Search::Wrapper::Component.new(
              organization: lookbook_organization,
              pagy:,
              bikes:,
              per_page: 10,
              params: {}
            )
          end

          # On the registrations search the panel is a band opened from this card's header,
          # and the page div outside it — not the card — runs the column toggle
          # @display legacy_stylesheet true
          def search_page
            return missing_notice("an organization") if lookbook_organization.blank?

            settings = ComponentStructs::OrgSearchSettings.new(organization: lookbook_organization)
            component = Pages::Org::Search::Wrapper::Component.new(
              organization: lookbook_organization, pagy:, bikes:, per_page: 10, params: {},
              settings:, search_page: true
            )
            {template: "pages/org/search/wrapper/component_preview/search_page",
             locals: {settings:, component:}}
          end

          private

          def pagy
            Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
          end

          def bikes
            return Bike.none if Rails.env.production? || lookbook_organization&.bikes.blank?

            lookbook_organization.bikes.limit(5)
          end
        end
      end
    end
  end
end
