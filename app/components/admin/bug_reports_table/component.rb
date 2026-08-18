# frozen_string_literal: true

module Admin
  module BugReportsTable
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "0d7ced6958ab"

      def initialize(collection:, render_sortable: false)
        @collection = collection
        @render_sortable = render_sortable
      end

      private

      def cache_key
        "admin-bug-reports-#{MARKUP_DIGEST}"
      end
    end
  end
end
