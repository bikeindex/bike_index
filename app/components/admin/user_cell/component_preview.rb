# frozen_string_literal: true

module Admin::UserCell
  class ComponentPreview < ApplicationComponentPreview
    # @group User Cell Variants

    def default
      render(Admin::UserCell::Component.new(user:))
    end

    def missing_user
      render(Admin::UserCell::Component.new(user_id: 999999, email: "missing@example.com"))
    end

    def email_only
      render(Admin::UserCell::Component.new(email: "orphaned@example.com"))
    end

    def with_search
      render(Admin::UserCell::Component.new(user:, render_search: true))
    end

    def without_search
      render(Admin::UserCell::Component.new(user:, render_search: false))
    end

    private

    def user
      User.find_by_id(88)
    end
  end
end
