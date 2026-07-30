# frozen_string_literal: true

module Admin
  module UsersTable
    # The admin users index table. Pass render_sortable to enable sort links, and
    # render_deleted to show the deleted_at column.
    class Component < ApplicationComponent
      # UI::Table caches each row without digesting the cells rendered into it, so the
      # key carries a digest of them. The cached_markup_digest spec keeps MARKUP_DIGEST
      # current, following the components the cells render.
      MARKUP_DIGEST = "7e9cff5b0801"

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
