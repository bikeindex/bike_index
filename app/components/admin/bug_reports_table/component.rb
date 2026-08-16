# frozen_string_literal: true

module Admin
  module BugReportsTable
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "0bfebf42b51a"

      def initialize(collection:, searchable_tags:, sortable_search_params: {}, display_dev_info: false, sort: nil, sort_direction: nil, render_sortable: false)
        @collection = collection
        @sort = sort
        @sort_direction = sort_direction
        @searchable_tags = searchable_tags
        @sortable_search_params = sortable_search_params
        @display_dev_info = display_dev_info
        @render_sortable = render_sortable
      end

      private

      def cache_key
        "admin-bug-reports-#{MARKUP_DIGEST}"
      end
    end
  end
end
