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
          # Descendant selectors, so they outrank the cell classes UI::Table gives every column
          TABLE_CLASSES = [
            "tw:[&_th]:whitespace-nowrap tw:[&_th]:border-b tw:[&_th]:border-gray-100 tw:[&_th]:bg-gray-50",
            "tw:[&_th]:px-4 tw:[&_th]:py-2.5 tw:[&_th]:text-2xs tw:[&_th]:font-normal tw:[&_th]:text-gray-400 tw:[&_th]:uppercase",
            # twlink's blue gives way to the header's gray, underlined like twlink-underlined
            "tw:[&_th_a]:text-inherit tw:[&_th_a]:underline tw:[&_th_a:hover]:decoration-2 tw:[&_th_a[data-active]]:decoration-2",
            "tw:[&_td]:bg-white tw:[&_td]:px-4 tw:[&_td]:py-2.5 tw:[&_td]:text-sm tw:[&_tr:hover_td]:bg-amber-50",
            # Whatever follows the table draws the line under it
            "tw:[&_tbody_tr:last-child_td]:border-b-0",
            "tw:dark:[&_th]:border-gray-700 tw:dark:[&_th]:bg-gray-800 tw:dark:[&_td]:bg-gray-900",
            "tw:dark:[&_tr:hover_td]:bg-gray-800"
          ].join(" ").freeze

          # The organization's registration fields that follow a column, in order. The rest come
          # after the columns every organization has
          REG_FIELDS_AFTER = {
            owner_name: %w[reg_phone reg_student_id reg_organization_affiliation],
            serial_number: %w[reg_extra_registration_number]
          }.freeze

          THUMB_CLASSES = "tw:block tw:h-8 tw:w-11 tw:rounded-lg tw:border tw:border-gray-200 tw:dark:border-gray-700"

          def initialize(organization:, bikes:, render_sortable: false,
            sort_state: ComponentStructs::SortState.new, bike_sticker: nil, settings: nil)
            @organization = organization
            @bikes = bikes
            @render_sortable = render_sortable
            @sort_state = sort_state
            @bike_sticker = bike_sticker
            @settings = settings
          end

          private

          # Column labels and additional fields derive from the organization alone, so bare
          # settings are enough when a caller (e.g. Wrapper) doesn't pass its own in.
          def settings
            @settings ||= ComponentStructs::OrgSearchSettings.new(organization: @organization)
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
            return {controller: "ui--table-overflow"} unless @render_sortable
            attrs = {
              controller: "ui--table-overflow update-cached-sortable-links org--assign-bike-sticker",
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
