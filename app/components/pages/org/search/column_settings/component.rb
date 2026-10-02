# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ColumnSettings
        # The column-visibility panel, and the export form's column picker. Its sidecar holds the
        # copy for everything ComponentStructs::OrgSearchSettings names — the column labels and the filters.
        class Component < ApplicationComponent
          # A band the width of the card the caller opens it from, per Kelsey's redesign
          PANEL_CLASSES = "tw:border-b tw:border-gray-100 tw:px-5 tw:py-5 tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-900"

          # Whoever renders the collapse element declares it, so the key has one home
          COLLAPSE_DATA = {controller: "ui--collapse",
                           "ui--collapse-storage-key-value": "orgRegistrationColumnsOpen"}.freeze

          # Goes on the element wrapping this panel, which the caller renders — so class-level,
          # not an instance built only to read off. collapse: when the ColumnSettingsToggle is
          # inside it too
          def self.column_settings_data_attributes(controllers: nil, collapse: false)
            controllers = [controllers, (COLLAPSE_DATA[:controller] if collapse), "org--search org--search-column-settings"]
            {controller: controllers.compact.join(" ")}
              .merge(collapse ? COLLAPSE_DATA.except(:controller) : {})
          end

          # Opened from a Search::ColumnSettingsToggle the caller renders, inside the
          # element it gives COLLAPSE_DATA. open: renders it expanded, for a collapse without
          # a storage key (which would restore the stored state over it). export_headers: the
          # export form's checked headers, which makes it that form's always-open column fields
          def initialize(settings:, open: false, export_headers: nil)
            @settings = settings
            @export_headers = export_headers
            @open = open || export?
          end

          private

          def export? = !@export_headers.nil?

          # Each with its own all/none/default. The impound columns are the impound search's alone
          def column_groups
            return [{title: translation(".included_columns"), columns: export_columns}] if export?

            [{title: translation(".visible_columns"), columns: search_columns(@settings.panel_columns)},
              ({title: translation(".impound_columns"), columns: search_columns(@settings.impound_columns, default: true)} if @settings.impound_columns.any?)].compact
          end

          # Named for their cell, which the search's controller shows and hides by
          def search_columns(cell_names, default: nil)
            cell_names.map do |cell_name|
              always_visible = @settings.always_visible?(cell_name)
              {name: cell_name, value: cell_name, label: @settings.panel_labels[cell_name.to_sym],
               hint: @settings.panel_hint(cell_name), checked: always_visible, disabled: always_visible,
               default: default || default?(cell_name)}
            end
          end

          def export_columns
            @settings.export_columns.map do |cell_name, header|
              {name: "export[headers][]", value: header, label: @settings.panel_labels[cell_name.to_sym],
               checked: @export_headers.include?(header), default: default?(cell_name)}
            end
          end

          def default?(cell_name) = @settings.initially_checked_columns.include?(cell_name)

          def column_rows(columns) = (columns.size / 3.0).ceil

          # The search's controller hears each group's changes, all/none/default's included
          def checkboxes_data
            return {} if export?

            {"org--search-column-settings-target": "checkboxes",
             action: "change->org--search-column-settings#updateVisibleColumns"}
          end

          def checkbox_label(column)
            return column[:label] unless column[:hint]

            safe_join([column[:label], tag.small(column[:hint], class: "tw:block tw:text-gray-400 tw:dark:text-gray-500")])
          end
        end
      end
    end
  end
end
