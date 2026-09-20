# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        # The panel renders collapsed, so each preview opens it the way its caller does — the
        # box from its own settings button, the band from the results card's header. Both wrap
        # it in the column-toggle controllers the caller supplies, which share the org search's
        # localStorage: checking a box here changes what the real search page shows.
        class ComponentPreview < ApplicationComponentPreview
          # A box in the page flow, as a registration's other-registrations table opens it
          def default
            return missing_notice("an organization") if lookbook_organization.blank?

            {template: "pages/org/search/settings/component_preview/default",
             locals: {settings:, data: Component.column_toggle_data_attributes(settings)}}
          end

          # A band across the results card, whose header holds the trigger and the export
          def in_results_card
            return missing_notice("an organization") if lookbook_organization.blank?

            {template: "pages/org/search/settings/component_preview/in_results_card",
             locals: {settings:, data: card_data_attributes}}
          end

          private

          def settings
            @settings ||= ComponentStructs::OrgSearchSettings.new(organization: lookbook_organization)
          end

          # What Wrapper's card carries off the search page: the column toggle plus the collapse
          def card_data_attributes
            collapse = Component::COLLAPSE_DATA
            Component.column_toggle_data_attributes(settings, controllers: collapse[:controller])
              .merge(collapse.except(:controller))
          end
        end
      end
    end
  end
end
