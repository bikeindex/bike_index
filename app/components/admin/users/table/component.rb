# frozen_string_literal: true

module Admin
  module Users
    module Table
      # The admin users index table. Pass render_sortable to enable sort links, and
      # render_deleted to show the deleted_at column.
      class Component < ApplicationComponent
        # Digest of the markup inside the row cache — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "14786bbb305a"

        def initialize(users:, render_sortable: false, render_deleted: false)
          @users = users
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
end
