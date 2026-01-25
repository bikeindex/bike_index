# frozen_string_literal: true

module Admin::UserIcon
  class ComponentPreview < ApplicationComponentPreview
    # @group User Iicon Variants
    def default
      render(Admin::UserIcon::Component.new(user: lookbook_user))
    end

    def full_text
      render(Admin::UserIcon::Component.new(user: lookbook_user, full_text: true))
    end

    def banned
      render(Admin::UserIcon::Component.new(user: User.new(banned: true), full_text: true))
    end

    def no_user
      render(Admin::UserIcon::Component.new(user: nil))
    end
  end
end
