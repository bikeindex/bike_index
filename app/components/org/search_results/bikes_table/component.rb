# frozen_string_literal: true

module Org
  module SearchResults
    module BikesTable
      # The organization registrations table: bike rows with every org column.
      # Extracted from Org::Search::Wrapper so it can render on its own, without
      # the search form, column-toggle settings, or pagination (e.g. a user's other
      # registrations on the show page). Pass render_sortable to enable sort links.
      class Component < ApplicationComponent
        # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "8b4919d3a4b3"

        delegate :additional_registration_fields, :column_renames, to: :settings_component

        def initialize(organization:, bikes:, current_user: nil, render_sortable: false,
          cache_key: nil, sortable_search_params: {}, bike_sticker: nil, settings_component: nil)
          @organization = organization
          @bikes = bikes
          @current_user = current_user
          @render_sortable = render_sortable
          @cache_key = cache_key || "org-#{organization.id}-#{MARKUP_DIGEST}"
          @sortable_search_params = sortable_search_params
          @bike_sticker = bike_sticker
          @settings_component = settings_component
        end

        private

        # Column labels and additional fields derive from the organization alone, so
        # a bare settings component is enough when a caller (e.g. Wrapper)
        # doesn't pass its own already-built one in.
        def settings_component
          @settings_component ||= Org::Search::Settings::Component.new(organization: @organization)
        end

        def hidden_not_registered_tag
          @hidden_not_registered_tag ||= tag.em(
            translation(".hidden_not_registered", org_name: @organization.short_name),
            class: "less-strong tw:leading-snug tw:text-xs"
          )
        end

        def table_wrapper_data_attributes
          return {} unless @render_sortable
          attrs = {
            controller: "update-cached-sortable-links org--assign-bike-sticker",
            "update-cached-sortable-links-base-url-value": url_for(@sortable_search_params.merge(organization_id: @organization.to_param))
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
