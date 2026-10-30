# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ColumnSettings
        # UI::TableColumnSettings for an organization's registrations - the column panel, or the export
        # form's column picker. Its sidecar holds the copy for everything
        # ComponentStructs::OrgSearchSettings names — the column labels and the filters.
        class Component < ApplicationComponent
          STORAGE_KEY = "orgRegistrationColumns"

          # The impound records search's columns differ, so its choices are kept apart
          IMPOUND_STORAGE_KEY = "orgImpoundColumns"

          # Goes on the element holding the panel and its table, which the caller renders
          def self.column_settings_data_attributes(controllers: nil, orderable: true, impound: false)
            UI::TableColumnSettings::Component.data_attributes(storage_key: impound ? IMPOUND_STORAGE_KEY : STORAGE_KEY,
              controllers:, orderable:)
          end

          # Opened from a Search::ColumnSettingsToggle the caller renders. orderable: as given to
          # column_settings_data_attributes. export_headers: the export form's checked headers, which
          # makes it that form's column fields
          def initialize(settings:, orderable: true, export_headers: nil)
            @settings = settings
            @orderable = orderable
            @export_headers = export_headers
          end

          def call
            render(UI::TableColumnSettings::Component.new(**(@export_headers ? export_options : panel_options)))
          end

          private

          def panel_options
            {columns: @settings.panel_columns.to_h { [it, label(it)] }, defaults: @settings.initially_checked_columns,
             always_visible: ComponentStructs::OrgSearchSettings::ALWAYS_VISIBLE_COLUMNS,
             hints: @settings.panel_hints, orderable: @orderable, **search_panel_options}
          end

          # Each search copies the other's column order
          def search_panel_options
            if @settings.impound?
              {sections: {translation(".impound_search_columns") => @settings.impound_panel_columns},
               copy_order_from: {storage_key: STORAGE_KEY, label: translation(".copy_column_order_from_registrations_search")}}
            elsif @settings.impound_search?
              {copy_order_from: {storage_key: IMPOUND_STORAGE_KEY, label: translation(".copy_column_order_from_impounded_vehicles_search")}}
            else
              {}
            end
          end

          def export_options
            {columns: @settings.export_columns.to_h { |cell_name, header| [header, label(cell_name)] },
             defaults: @settings.default_export_headers, field_name: "export[headers][]", checked: @export_headers}
          end

          def label(cell_name) = @settings.panel_labels[cell_name.to_sym]
        end
      end
    end
  end
end
