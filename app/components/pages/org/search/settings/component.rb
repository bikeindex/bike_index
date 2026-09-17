# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        # The column-visibility panel, and the registry the rest of the org search reads its
        # labels out of - which is what keeps a column's name in this panel and in the table
        # header the same string.
        class Component < ApplicationComponent
          COLUMN_RENAME_KEYS = %i[
            created_at_cell
            updated_at_cell
            stolen_cell
            serial_number_cell
            manufacturer_cell
            model_cell
            color_cell
            owner_email_cell
            creation_description_cell
            owner_name_cell
            reg_organization_affiliation_cell
            reg_extra_registration_number_cell
            reg_phone_cell
            reg_address_cell
            reg_student_id_cell
            notes_cell
            sticker_cell
            impound_id_cell
            impounded_cell
            avery_cell
            cycle_type_cell
            propulsion_type_cell
            status_cell
            url_cell
          ].freeze

          ORG_PREFIXED_COLUMNS = %i[reg_organization_affiliation_cell reg_student_id_cell notes_cell].freeze

          PANEL_COLORS = "tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-900"

          # Each filter's values and their labels, once — `filter_groups` lays them out and
          # `active_search_filter_descriptions` names the ones in force. feature gates the
          # whole row, value_feature an individual option; blank is the row's "not filtering".
          FILTER_GROUPS = {
            search_stickers: {label: ".stickers", feature: "bike_stickers",
                              values: {with: ".filter_with_stickers_html", none: ".filter_no_sticker_html"}},
            search_address: {label: ".address", feature: "reg_address",
                             values: {with_street: ".filter_with_address_html",
                                      without_street: ".filter_no_address_html"}},
            search_status: {label: ".status", blank: "all",
                            value_feature: {not_impounded: "impound_bikes", impounded: "impound_bikes"},
                            values: {not_impounded: ".filter_not_impounded_html",
                                     impounded: ".filter_impounded_html",
                                     with_owner: ".filter_not_stolen_or_impounded_html",
                                     stolen: ".filter_stolen_html"}},
            search_unregisteredness: {label: ".unregistered",
                                      values: {only_unregistered: ".filter_only_unregistered_html",
                                               only_registered: ".filter_not_unregistered_html"}},
            search_parking_notification: {label: ".parking_notifications", feature: "parking_notifications",
                                          values: {with: ".filter_with_parking_notification_html",
                                                   none: ".filter_no_parking_notification_html"}}
          }.freeze

          attr_reader :organization

          def initialize(
            organization:,
            interpreted_params: {},
            sortable_search_params: {},
            params: {},
            search_stickers: nil,
            search_address: nil,
            search_status: "all",
            search_unregisteredness: nil,
            search_parking_notification: nil,
            search_all: false,
            toggle_button: true
          )
            @organization = organization
            @interpreted_params = interpreted_params
            @sortable_search_params = sortable_search_params
            @params = params
            @filter_values = {search_stickers:, search_address:, search_status:,
                              search_unregisteredness:, search_parking_notification:}
            @search_all = search_all
            # The registrations search opens this panel from its results-card header instead
            @toggle_button = toggle_button
          end

          def active_search_filter_descriptions
            FILTER_GROUPS.filter_map do |name, group|
              value = @filter_values[name]
              key = group[:values][value.to_sym] if value.is_a?(String)
              translation(key) if key
            end
          end

          def filter_groups
            FILTER_GROUPS.filter_map do |name, group|
              next unless enabled_filter?(group[:feature])

              blank = group[:blank] || ""
              {name:, label: translation(group[:label]),
               selected: @filter_values[name].presence || blank,
               entries: [{value: blank, label: translation(".all")}] + group_entries(group)}
            end
          end

          def notes_search_label = translation(".show_notes_search")

          def initially_checked_columns
            @initially_checked_columns ||= begin
              cols = %w[created_at_cell stolen_cell manufacturer_cell model_cell
                color_cell owner_email_cell owner_name_cell creation_description_cell]
              cols += ["sticker_cell"] if @organization.enabled?("bike_stickers")
              cols += ["impounded_cell"] if @params[:search_impoundedness] == "impounded"
              cols
            end
          end

          # A band the width of the card the caller opens it from, per Kelsey's redesign;
          # standing on its own it's a box in the page flow instead
          def panel_classes
            return "tw:border-b tw:border-gray-100 tw:px-4 tw:py-4 #{PANEL_COLORS}" unless @toggle_button

            "tw:my-4 tw:rounded-lg tw:border tw:border-gray-300/70 tw:px-3 tw:pt-4 tw:pb-3 #{PANEL_COLORS}"
          end

          # Nothing when the caller holds the button, and so the collapse element, itself
          def collapse_data_attributes
            return {} unless @toggle_button

            {controller: "ui--collapse", "ui--collapse-storage-key-value": "orgRegistrationColumnsOpen"}
          end

          # Stimulus wiring for the column-toggle panel, shared by every caller that renders it
          def column_toggle_data_attributes
            {controller: "org--search org--search-column-toggle",
             "org--search-column-toggle-default-columns-value": initially_checked_columns.to_json}
          end

          def column_renames
            @column_renames ||= COLUMN_RENAME_KEYS.map { |key|
              name = translation(".#{key}")
              name = "#{@organization.short_name} #{name}" if ORG_PREFIXED_COLUMNS.include?(key)
              [key, name]
            }.to_h
          end

          def additional_registration_fields
            @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
          end

          def cycle_type
            @cycle_type ||= begin
              merged = @params.merge(@interpreted_params)
              BikeServices::Displayer.vehicle_search?(merged) ? translation(".vehicle") : translation(".bike")
            end
          end

          def render_export?
            @organization.enabled?("csv_exports") && !@search_all
          end

          def enabled_columns
            @enabled_columns ||= begin
              cols = initially_checked_columns.dup
              cols += %w[url_cell updated_at_cell serial_number_cell cycle_type_cell propulsion_type_cell status_cell]
              cols += additional_registration_fields.map { |f| "#{f}_cell" }
              cols += ["notes_cell"] if @organization.enabled?("registration_notes")
              cols += %w[impound_id_cell impounded_cell] if @organization.enabled?("impound_bikes")
              cols += ["avery_cell"] if @organization.enabled?("avery_export")
              cols.uniq.sort { |a, b| column_renames[a.to_sym] <=> column_renames[b.to_sym] }
            end
          end

          # Public for the caller that renders the export button itself, which can't call
          # export_path here - a route helper needs the component it's on to be rendering
          def search_params
            @search_params ||= (@sortable_search_params || {}).merge((@interpreted_params || {}).merge(organization_id: @organization.to_param))
          end

          private

          def export_path
            organization_registrations_path(search_params.merge(create_export: true))
          end

          def enabled_filter?(feature)
            feature.nil? || @organization.enabled?(feature)
          end

          def group_entries(group)
            group[:values].filter_map do |value, key|
              next unless enabled_filter?(group[:value_feature]&.dig(value))

              {value: value.to_s, label: translation(key)}
            end
          end
        end
      end
    end
  end
end
