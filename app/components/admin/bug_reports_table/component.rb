# frozen_string_literal: true

module Admin
  module BugReportsTable
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "d0e79ffa924e"

      def initialize(collection:, searchable_tags:, sort_state: ComponentStates::SortState.new, display_dev_info: false, render_sortable: false)
        @collection = collection
        @searchable_tags = searchable_tags
        @sort_state = sort_state
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
