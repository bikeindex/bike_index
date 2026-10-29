# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module BikesTable
        # The organization registrations table: bike rows with every org column.
        # Extracted from Pages::Org::Search::Wrapper so it can render on its own, without
        # the search form, column settings, or pagination (e.g. a user's other
        # registrations on the show page). Pass render_sortable to enable sort links.
        class Component < ApplicationComponent
          # The organization's registration fields that follow a column, in order. The rest come
          # after the columns every organization has
          REG_FIELDS_AFTER = {
            owner_name: %w[reg_phone reg_student_id reg_organization_affiliation],
            serial_number: %w[reg_extra_registration_number]
          }.freeze

          # The impound records' multi-update form, which the checkboxes reach with form= - here
          # rather than on the form, which the cached rows would then have to digest
          MULTI_UPDATE_FORM_ID = "impoundRecordsMultiUpdateForm"

          # impound_records: an impound search's rows, in place of bikes - which adds the impound
          # columns and the multi-update checkboxes, shown with multiselect_visible
          def initialize(organization:, bikes: [], impound_records: nil, multiselect_visible: false,
            render_sortable: false, sort_state: ComponentStructs::SortState.new, bike_sticker: nil, settings: nil)
            @organization = organization
            @bikes = bikes
            @impound_records = impound_records
            @multiselect_visible = multiselect_visible
            @render_sortable = render_sortable
            @sort_state = sort_state
            @bike_sticker = bike_sticker
            @settings = settings
          end

          private

          # Column labels and additional fields derive from the organization alone, so bare
          # settings are enough when a caller (e.g. Wrapper) doesn't pass its own in.
          def settings
            @settings ||= ComponentStructs::OrgSearchSettings.new(organization: @organization, impound: impound?)
          end

          def impound? = !@impound_records.nil?

          def cache_key = [@organization, self.class.cache_digest, (@multiselect_visible if impound?)]

          # Everything an impound row renders besides its record. The claims decide its checkbox's
          # update kinds, and a claim's writes don't touch the record
          def cache_records
            ->(impound_record) { [impound_record.bike, impound_record.user, impound_record.impounded_from_address_record, *impound_record.impound_claims] } if impound?
          end

          def multiselect_cell_classes
            ["multi-update-cell table-cell-check", ("tw:hidden" unless @multiselect_visible)].compact.join(" ")
          end

          # The organization's fields placed after column, or with :rest the ones placed nowhere
          def reg_fields_after(column)
            fields = settings.additional_registration_fields
            return fields - REG_FIELDS_AFTER.values.flatten if column == :rest

            REG_FIELDS_AFTER.fetch(column) & fields
          end

          def hidden_not_registered_tag
            render(UI::Tooltip::Component.new(text: hidden_tooltip_text)) { hidden_label }
          end

          def hidden_label
            @hidden_label ||= tag.em(translation(".hidden"), class: "less-strong tw:leading-snug tw:text-xs")
          end

          def hidden_tooltip_text
            @hidden_tooltip_text ||= translation(".not_registered_with", org_name: @organization.short_name)
          end

          def table_wrapper_data_attributes
            return {} unless @render_sortable
            attrs = {
              controller: "update-cached-sortable-links org--assign-bike-sticker",
              "update-cached-sortable-links-base-url-value": url_for(@sort_state.search_params.merge(organization_id: @organization.to_param))
            }
            if @bike_sticker.present?
              attrs[:"org--assign-bike-sticker-sticker-path-value"] = bike_sticker_path(id: @bike_sticker.code, organization_id: @bike_sticker.organization_id)
            end
            attrs
          end
        end
      end
    end
  end
end
