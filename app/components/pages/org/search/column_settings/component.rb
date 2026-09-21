# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ColumnSettings
        # The column-visibility panel. Its sidecar holds the copy for everything
        # ComponentStructs::OrgSearchSettings names — the column labels and the filters.
        class Component < ApplicationComponent
          # A band the width of the card the caller opens it from, per Kelsey's redesign
          PANEL_CLASSES = "tw:border-b tw:border-gray-100 tw:px-5 tw:py-5 tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-900"

          # Whoever renders the collapse element declares it, so the key has one home
          COLLAPSE_DATA = {controller: "ui--collapse",
                           "ui--collapse-storage-key-value": "orgRegistrationColumnsOpen"}.freeze

          # Goes on the element wrapping this panel, which the caller renders — so class-level,
          # not an instance built only to read off. collapse: when the ColumnSettingsToggle is
          # inside it too
          def self.column_settings_data_attributes(settings, controllers: nil, collapse: false)
            controllers = [controllers, (COLLAPSE_DATA[:controller] if collapse), "org--search org--search-column-settings"]
            {controller: controllers.compact.join(" "),
             "org--search-column-settings-default-columns-value": settings.initially_checked_columns.to_json}
              .merge(collapse ? COLLAPSE_DATA.except(:controller) : {})
          end

          # Opened from a Search::ColumnSettingsToggle the caller renders, inside the
          # element it gives COLLAPSE_DATA
          def initialize(settings:)
            @settings = settings
          end
        end
      end
    end
  end
end
