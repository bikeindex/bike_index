# frozen_string_literal: true

module Admin::UserCell
  class ComponentPreview < ApplicationComponentPreview
    def default
      user = User.first
      render(Admin::UserCell::Component.new(user: user))
    end

    def missing_user
      render(Admin::UserCell::Component.new(user_id: 999999, email: "missing@example.com"))
    end

    def email_only
      render(Admin::UserCell::Component.new(email: "orphaned@example.com"))
    end

    def with_search
      user = User.first
      render(Admin::UserCell::Component.new(user: user, render_search: true))
    end

    def without_search
      user = User.first
      render(Admin::UserCell::Component.new(user: user, render_search: false))
    end
  end
end
