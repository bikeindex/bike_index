# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      # Renders the registration show page as the resolved [kind, organization]
      # perspective (e.g. [:public, nil] or [:staff, org]) and fragment-caches it.
      class Component < ApplicationComponent
        def initialize(bike:, current_user:, view:, available_views:)
          @bike = bike
          @current_user = current_user
          @view = view
          @available_views = available_views
        end

        private

        def inner_component
          kind, organization = @view
          if organization
            OrgAdmin::Component.new(bike: @bike, current_user: @current_user, organization:,
              staff: kind == :staff, available_views: @available_views)
          else
            Consumer::Component.new(bike: @bike, current_user: @current_user, owner: kind == :owner,
              show_for_sale: @bike.is_for_sale?, available_views: @available_views)
          end
        end

        # Keyed on the viewer for the admin view's per-user content. This key can't
        # keep cached forms' CSRF tokens valid (they're session-scoped, and a user's
        # session varies across devices/logins) — the csrf-refresh controller reissues
        # them client-side from the meta tag.
        def cache_key
          ["registrations/show", @current_user&.id, BikeServices::ShowViews.view_param(@view), @bike.cache_key_with_version]
        end
      end
    end
  end
end
