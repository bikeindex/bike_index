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
            "tw:[&_td]:bg-white tw:[&_td]:px-4 tw:[&_td]:py-3 tw:[&_td]:text-sm tw:[&_tr:hover_td]:bg-amber-50",
            # Whatever follows the table draws the line under it
            "tw:[&_tbody_tr:last-child_td]:border-b-0",
            "tw:dark:[&_th]:border-gray-700 tw:dark:[&_th]:bg-gray-800 tw:dark:[&_td]:bg-gray-900",
            "tw:dark:[&_tr:hover_td]:bg-gray-800"
          ].join(" ").freeze

          # Frozen against the table's horizontal scroll, with a shadow once there's any to scroll
          VIEW_COLUMN_CLASSES = "tw:w-px tw:sticky tw:left-0 tw:z-1 tw:border-r tw:border-r-gray-100 " \
            "tw:group-data-overflowing/bikes-table:shadow-[2px_0_6px_rgba(26,26,31,0.04)] tw:dark:border-r-gray-700"

          # [&>div] is UI::Table's scroller, whose bottom margin and padding would part the table
          # from what follows it. The after: box mirrors the View column over the right edge while
          # there's more to scroll to - its border the divider line, its shadow falling on the rows,
          # the rest of it past the edge in the search card's clip - except in a full-bleed row,
          # where the table runs off the page's edge
          WRAPPER_CLASSES = "tw:group/bikes-table tw:relative tw:[&>div]:mb-0 tw:[&>div]:pb-0 tw:data-overflowing:after:absolute " \
            "tw:data-overflowing:after:inset-y-0 tw:data-overflowing:after:left-[calc(100%-1px)] tw:data-overflowing:after:z-2 " \
            "tw:data-overflowing:after:w-4 tw:data-overflowing:after:border-l tw:data-overflowing:after:border-gray-100 " \
            "tw:data-overflowing:after:shadow-[-2px_0_6px_rgba(26,26,31,0.04)] tw:dark:data-overflowing:after:border-gray-700 " \
            "tw:@max-[672px]/twwiderow:after:hidden"

          def initialize(organization:, bikes:, current_user: nil, render_sortable: false,
            sort_state: ComponentStructs::SortState.new, bike_sticker: nil, settings: nil)
            @organization = organization
            @bikes = bikes
            @current_user = current_user
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

          def hidden_not_registered_tag
            safe_join([hidden_label, hidden_tooltip], " ")
          end

          def hidden_label
            @hidden_label ||= tag.em(translation(".hidden"), class: "less-strong tw:leading-snug tw:text-xs")
          end

          # Rendered per cell rather than memoized with its text: the trigger points at its
          # own tooltip by id
          def hidden_tooltip
            render(UI::Tooltip::Component.new(text: hidden_tooltip_text)) do |tooltip|
              tooltip.with_tooltip_button(class: hidden_tooltip_button_class)
            end
          end

          # As quiet as the word it sits beside
          def hidden_tooltip_button_class
            @hidden_tooltip_button_class ||= "#{UI::Tooltip::Component::BUTTON_CLASS} tw:opacity-60"
          end

          def hidden_tooltip_text
            @hidden_tooltip_text ||= translation(".not_registered_with", org_name: @organization.short_name)
          end

          def table_wrapper_data_attributes
            return {controller: "org--bikes-table-overflow"} unless @render_sortable
            attrs = {
              controller: "org--bikes-table-overflow update-cached-sortable-links org--assign-bike-sticker",
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
