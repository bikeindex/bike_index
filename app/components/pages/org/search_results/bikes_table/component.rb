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
