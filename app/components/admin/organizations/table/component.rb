# frozen_string_literal: true

module Admin
  module Organizations
    module Table
      # The admin organizations index table, also rendered on the admin dashboard.
      class Component < ApplicationComponent
        # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "4c3467b402d4"

        def initialize(organizations:, render_sortable: false, render_deleted: false)
          @organizations = organizations
          @render_sortable = render_sortable
          @render_deleted = render_deleted
        end

        private

        def cache_key = "admin-organizations-#{MARKUP_DIGEST}"

        def pos_link(organization)
          display = organization.pos_kind.to_s.gsub("pos", "")

          link_to display.humanize,
            admin_organizations_path(helpers.sortable_search_params.merge(search_pos: organization.pos_kind)),
            class: display.match?("broken") ? "text-warning" : "gray-link"
        end
      end
    end
  end
end
