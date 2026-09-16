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

          FILTER_DESCRIPTION_KEYS = {
            search_stickers: {with: ".filter_with_stickers_html", none: ".filter_no_sticker_html"},
            search_address: {with_street: ".filter_with_address_html", without_street: ".filter_no_address_html"},
            search_status: {not_impounded: ".filter_not_impounded_html", impounded: ".filter_impounded_html",
                            with_owner: ".filter_not_stolen_or_impounded_html", stolen: ".filter_stolen_html"},
            search_parking_notification: {with: ".filter_with_parking_notification_html",
                                          none: ".filter_no_parking_notification_html"}
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
            search_parking_notification: nil,
            bike_sticker: nil,
            search_all: false,
            toggle_button: true
          )
            @organization = organization
            @interpreted_params = interpreted_params
            @sortable_search_params = sortable_search_params
            @params = params
            @search_stickers = search_stickers
            @search_address = search_address
            @search_status = search_status
            @search_parking_notification = search_parking_notification
            @bike_sticker = bike_sticker
            @search_all = search_all
            # The registrations search opens this panel from its results-card header instead
            @toggle_button = toggle_button
          end

          def active_search_filter_descriptions
            FILTER_DESCRIPTION_KEYS.filter_map do |param, mapping|
              value = filter_values[param]
              key = mapping[value.to_sym] if value.is_a?(String)
              translation(key) if key
            end
          end

          def filter_groups
            [sticker_group, address_group, status_group, parking_notification_group].compact
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

          def search_params
            @search_params ||= (@sortable_search_params || {}).merge((@interpreted_params || {}).merge(organization_id: @organization.to_param))
          end

          private

          def export_path
            organization_registrations_path(search_params.merge(create_export: true))
          end

          def filter_values
            {search_stickers: @search_stickers, search_address: @search_address,
             search_status: @search_status, search_parking_notification: @search_parking_notification}
          end

          def group(name, label_key, selected, entries)
            {name:, label: translation(label_key), selected: selected.presence || "", entries:}
          end

          def sticker_group
            return nil unless @organization.enabled?("bike_stickers")

            group(:search_stickers, ".stickers", @search_stickers,
              [{value: "", label: translation(".all")},
                {value: "with", label: translation(".filter_with_stickers_html")},
                {value: "none", label: translation(".filter_no_sticker_html")}])
          end

          def address_group
            return nil unless @organization.enabled?("reg_address")

            group(:search_address, ".address", @search_address,
              [{value: "", label: translation(".all")},
                {value: "with_street", label: translation(".filter_with_address_html")},
                {value: "without_street", label: translation(".filter_no_address_html")}])
          end

          def status_group
            entries = [{value: "all", label: translation(".all")}]
            if @organization.enabled?("impound_bikes")
              entries << {value: "not_impounded", label: translation(".filter_not_impounded_html")}
              entries << {value: "impounded", label: translation(".filter_impounded_html")}
            end
            entries << {value: "with_owner", label: translation(".filter_not_stolen_or_impounded_html")}
            entries << {value: "stolen", label: translation(".filter_stolen_html")}

            group(:search_status, ".status", @search_status, entries)
          end

          def parking_notification_group
            return nil unless @organization.enabled?("parking_notifications")

            group(:search_parking_notification, ".parking_notifications", @search_parking_notification,
              [{value: "", label: translation(".all")},
                {value: "with", label: translation(".filter_with_parking_notification_html")},
                {value: "none", label: translation(".filter_no_parking_notification_html")}])
          end
        end
      end
    end
  end
end
