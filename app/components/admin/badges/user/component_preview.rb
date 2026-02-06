# frozen_string_literal: true

module Admin::Badges::User
  class ComponentPreview < ApplicationComponentPreview
    # @group User Badge Variants
    def default
      render(Admin::Badges::User::Component.new(user: lookbook_user))
    end

    def full_text
      render(Admin::Badges::User::Component.new(user: lookbook_user, full_text: true))
    end

    def multiple_badges
      render(Admin::Badges::User::Component.new(user: multi_badge_user, full_text: true))
    end

    def banned
      render(Admin::Badges::User::Component.new(user: ::User.new(banned: true), full_text: true))
    end

    def no_user
      render(Admin::Badges::User::Component.new(user: nil))
    end
    # @endgroup

    private

    def multi_badge_user
      if ENV["LOOKBOOK_SECONDARY_USER_ID"].present?
        ::User.find(ENV["LOOKBOOK_SECONDARY_USER_ID"])
      else
        ::User.new
      end
    end
  end
end
