# frozen_string_literal: true

module Admin
  module OrganizationsTable
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "365f1baad39f"

      def initialize(organizations:, render_sortable: false, render_deleted: false)
        @organizations = organizations
        @render_sortable = render_sortable
        @render_deleted = render_deleted
      end

      private

      def column(attribute, label = nil)
        helpers.sortable(attribute, label, render_sortable: @render_sortable)
      end

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
