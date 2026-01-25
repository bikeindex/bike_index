# frozen_string_literal: true

module Admin::UserIcon
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Admin::UserIcon::Component.new(user:))
    end

    def full_text
      render(Admin::UserIcon::Component.new(user:, full_text: true))
    end

    def no_user
      render(Admin::UserIcon::Component.new(user: nil))
    end

    private

    def user
      User.find_by_id(88)
    end
  end
end
