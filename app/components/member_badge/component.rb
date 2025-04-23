# frozen_string_literal: true

module MemberBadge
  class Component < ApplicationComponent
    def initialize(level: nil, shadow: false, classes: "")
      @level = level
      @shadow = shadow
      @classes = classes
    end

    def render?
      @level.present?
    end

    private

    def image_path
      "membership/badge_#{@level}#{@shadow ? "-shadow" : ""}.png"
    end

    def badge_alt_text
      "#{@level} membership badge"
    end
  end
end
