# frozen_string_literal: true

module MemberBadge
  class Component < ApplicationComponent
    def initialize(level: nil, size: :md)
      @level = level
      @size = size
    end

    def render?
      @level.present?
    end
  end
end
