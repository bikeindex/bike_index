# frozen_string_literal: true

module Admin
  module OrganizationsTable
    # The admin organizations index table, also rendered on the admin dashboard.
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "48bae88f2131"

      def initialize(organizations:, render_sortable: false, render_deleted: false)
        @organizations = organizations
        @render_sortable = render_sortable
        @render_deleted = render_deleted
      end

      private

      def cache_key = "admin-organizations-#{MARKUP_DIGEST}"

      def regional_parent_names(organization)
        organization.regional_parents.pluck(:short_name)
      end

      def pos_kind_display(organization)
        organization.pos_kind.to_s.gsub("pos", "")
      end

      def pos_link_class(organization)
        pos_kind_display(organization).match?("broken") ? "text-warning" : "gray-link"
      end

      def kind_path(organization)
        admin_organizations_path(helpers.sortable_search_params.merge(search_kind: organization.kind))
      end

      def pos_path(organization)
        admin_organizations_path(helpers.sortable_search_params.merge(search_pos: organization.pos_kind))
      end
    end
  end
end
