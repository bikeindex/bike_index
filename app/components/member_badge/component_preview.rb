# frozen_string_literal: true

module MemberBadge
  class ComponentPreview < ApplicationComponentPreview
    # @group Level Variants
    # @param level "The membership level"
    def none(level: nil)
      render(MemberBadge::Component.new(level:))
    end

    def basic(level: :basic)
      render(MemberBadge::Component.new(level:))
    end

    def plus(level: :plus)
      render(MemberBadge::Component.new(level:))
    end

    def patron(level: :patron)
      render(MemberBadge::Component.new(level:))
    end
  end
end
