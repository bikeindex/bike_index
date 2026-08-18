# frozen_string_literal: true

module Admin
  module UsersTable
    # The admin users index table. Pass render_sortable to enable sort links, and
    # render_deleted to show the deleted_at column.
    class Component < ApplicationComponent
      # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "d1a26e8508a9"

      def initialize(users:, sort_state: ComponentStates::SortState.new, display_dev_info: false, render_sortable: false, render_deleted: false)
        @users = users
        @sort_state = sort_state
        @display_dev_info = display_dev_info
        @render_sortable = render_sortable
        @render_deleted = render_deleted
      end

      private

      def cache_key
        "admin-users-#{MARKUP_DIGEST}"
      end
    end
  end
end
