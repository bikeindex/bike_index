# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      # Renders the registration show page as the resolved perspective (:public,
      # :owner, or an [organization, role] admin view) and fragment-caches it.
      class Component < ApplicationComponent
        def initialize(bike:, current_user:, view:, available_views:, mapbox_key: nil)
          @bike = bike
          @current_user = current_user
          @view = view
          @available_views = available_views
          @mapbox_key = mapbox_key
        end

        private

        def inner_component
          if @view.is_a?(Array) # [organization, role]
            organization, role = @view
            OrgAdmin::Component.new(bike: @bike, current_user: @current_user, organization:,
              staff: role == :staff, mapbox_key: @mapbox_key, available_views: @available_views)
          else
            Consumer::Component.new(bike: @bike, current_user: @current_user, owner: @view == :owner,
              show_for_sale: @bike.is_for_sale?, mapbox_key: @mapbox_key, available_views: @available_views)
          end
        end

        # Keyed on the viewer for the admin view's per-user content. This key can't
        # keep cached forms' CSRF tokens valid (they're session-scoped, and a user's
        # session varies across devices/logins) — the csrf-refresh controller reissues
        # them client-side from the meta tag.
        def cache_key
          ["registrations/show", @current_user&.id, view_param, @bike.cache_key_with_version]
        end

        def view_param
          return @view.to_s unless @view.is_a?(Array)

          organization, role = @view
          "#{organization.to_param}.#{role}"
        end
      end
    end
  end
end
