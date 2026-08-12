# frozen_string_literal: true

module Admin
  module BugReportsTable
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "2634672a3dc2"

      def initialize(collection:, render_sortable: false)
        @collection = collection
        @render_sortable = render_sortable
      end

      private

      # The user is in the key because the sender cell renders their badges
      def row_cache_key(bug_report)
        ["admin_bug_report", MARKUP_DIGEST, bug_report, bug_report.user]
      end
    end
  end
end
