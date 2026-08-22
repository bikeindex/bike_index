# frozen_string_literal: true

module Admin
  module Organizations
    module Table
      # The admin organizations index table, also rendered on the admin dashboard.
      class Component < ApplicationComponent
        # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "af6825ff2b7c"

        def initialize(organizations:, sort_state: ComponentStates::SortState.new,
          render_sortable: false, render_deleted: false)
          @organizations = organizations
          @sort_state = sort_state
          @render_sortable = render_sortable
          @render_deleted = render_deleted
        end

        private

        def cache_key = "admin-organizations-#{MARKUP_DIGEST}"

        def pos_link(organization)
          display = organization.pos_kind.to_s.gsub("pos", "")

          # A fixed path rather than the current search params, which the row cache would bake in
          link_to display.humanize,
            admin_organizations_path(search_pos: organization.pos_kind),
            class: display.match?("broken") ? "text-warning" : "gray-link"
        end
      end
    end
  end
end
