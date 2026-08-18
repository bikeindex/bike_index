# frozen_string_literal: true

module Admin
  module BikesTable
    # The admin bikes index table, also rendered wherever admin lists bikes (the
    # dashboard, an organization, a bulk import, duplicate groups). Pass
    # render_sortable to enable sort links, render_multi_check for the delete
    # checkboxes, and skip_user to drop the owner column.
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "abd0fef28861"

      def initialize(bikes:, no_show_header: false, show_serial: false, render_sortable: false,
        skip_user: false, render_multi_check: false)
        @bikes = bikes
        @no_show_header = no_show_header
        @show_serial = show_serial
        @render_sortable = render_sortable
        @skip_user = skip_user
        @render_multi_check = render_multi_check
      end

      private

      def cache_key
        "admin-bikes-#{MARKUP_DIGEST}"
      end

      def show_serial?
        @show_serial || helpers.params[:show_serial].present?
      end

      def skip_manufacturer_link?
        helpers.params[:search_manufacturer].present?
      end
    end
  end
end
