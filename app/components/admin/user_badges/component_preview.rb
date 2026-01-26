# frozen_string_literal: true

module Admin::UserBadges
  class ComponentPreview < ApplicationComponentPreview
    # @group User Badge Variants
    def default
      render(Admin::UserBadges::Component.new(user: lookbook_user))
    end

    def full_text
      render(Admin::UserBadges::Component.new(user: lookbook_user, full_text: true))
    end

    def banned
      render(Admin::UserBadges::Component.new(user: User.new(banned: true), full_text: true))
    end

    def no_user
      render(Admin::UserBadges::Component.new(user: nil))
    end
  end
end
