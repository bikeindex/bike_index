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
          # element it gives COLLAPSE_DATA. open: renders it expanded, for a collapse without
          # a storage key (which would restore the stored state over it)
          def initialize(settings:, open: false)
            @settings = settings
            @open = open
          end

          private

          # Named for their cell, which the search's controller shows and hides by
          def columns
            @settings.panel_columns.map do |cell_name|
              always_visible = @settings.always_visible?(cell_name)
              {name: cell_name, value: cell_name, label: @settings.panel_labels[cell_name.to_sym],
               checked: always_visible, disabled: always_visible,
               default: @settings.initially_checked_columns.include?(cell_name)}
            end
          end
        end
      end
    end
  end
end
