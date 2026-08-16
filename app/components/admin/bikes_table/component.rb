# frozen_string_literal: true

module Admin
  module BikesTable
    # The admin bikes index table, also rendered wherever admin lists bikes (the
    # dashboard, an organization, a bulk import, duplicate groups). Pass
    # render_sortable to enable sort links, render_multi_check for the delete
    # checkboxes, and skip_user to drop the owner column.
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "575c6f1205ce"

      def initialize(bikes:, sortable_search_params: {}, display_dev_info: false, sort: nil, sort_direction: nil, no_show_header: false,
        show_serial: false, skip_manufacturer_link: false, render_sortable: false,
        skip_user: false, render_multi_check: false)
        @bikes = bikes
        @sort = sort
        @sort_direction = sort_direction
        @sortable_search_params = sortable_search_params
        @display_dev_info = display_dev_info
        @no_show_header = no_show_header
        @show_serial = show_serial
        @skip_manufacturer_link = skip_manufacturer_link
        @render_sortable = render_sortable
        @skip_user = skip_user
        @render_multi_check = render_multi_check
      end

      private

      def cache_key
        "admin-bikes-#{MARKUP_DIGEST}"
      end
    end
  end
end
