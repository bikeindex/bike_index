# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        # The column-visibility panel. Its sidecar holds the copy for everything
        # ComponentStructs::OrgSearchSettings names — the column labels and the filters —
        # since a component's own directory is the only home MARKUP_DIGEST reaches.
        class Component < ApplicationComponent
          PANEL_COLORS = "tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-900"

          # Whoever renders the collapse element declares it, so the key has one home
          COLLAPSE_DATA = {controller: "ui--collapse",
                           "ui--collapse-storage-key-value": "orgRegistrationColumnsOpen"}.freeze

          # Goes on the element wrapping this panel, which the caller renders — so class-level,
          # not an instance built only to read off
          def self.column_toggle_data_attributes(settings, controllers: nil)
            {controller: [controllers, "org--search org--search-column-toggle"].compact.join(" "),
             "org--search-column-toggle-default-columns-value": settings.initially_checked_columns.to_json}
          end

          # toggle_button: false for the registrations search, which opens this panel from its
          # results-card header, and renders the export button up there beside it
          def initialize(settings:, toggle_button: true)
            @settings = settings
            @toggle_button = toggle_button
          end

          private

          # A band the width of the card the caller opens it from, per Kelsey's redesign;
          # standing on its own it's a box in the page flow instead
          def panel_classes
            return "tw:border-b tw:border-gray-100 tw:px-4 tw:py-4 #{PANEL_COLORS}" unless @toggle_button

            "tw:my-4 tw:rounded-lg tw:border tw:border-gray-300/70 tw:px-3 tw:pt-4 tw:pb-3 #{PANEL_COLORS}"
          end

          # Nothing when the caller holds the button, and so the collapse element, itself
          def collapse_data_attributes
            return {} unless @toggle_button

            COLLAPSE_DATA
          end

          def export_path
            organization_registrations_path(@settings.search_params.merge(create_export: true))
          end
        end
      end
    end
  end
end
