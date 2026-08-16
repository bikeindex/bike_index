# frozen_string_literal: true

module Admin
  module UserCell
    class ComponentPreview < ApplicationComponentPreview
      # @!group User Cell Variants
      def default
        render(Admin::UserCell::Component.new(user: lookbook_user))
      end

      def missing_user
        render(Admin::UserCell::Component.new(user_id: 999999, email: "missing@example.com"))
      end

      def email_only
        render(Admin::UserCell::Component.new(email: "orphaned@example.com"))
      end

      def with_search
        render(Admin::UserCell::Component.new(user: lookbook_user, search_url: admin_users_path(user_id: lookbook_user.id), render_search: true))
      end

      def without_search
        render(Admin::UserCell::Component.new(user: lookbook_user, search_url: admin_users_path(user_id: lookbook_user.id), render_search: false))
      end
    end
  end
end
