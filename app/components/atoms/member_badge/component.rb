# frozen_string_literal: true

module Atoms
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

      def call
        image_tag(image_path, alt: badge_alt_text, class: @classes)
      end

      private

      def image_path
        "membership/badge_#{@level}#{"-shadow" if @shadow}.png"
      end

      def badge_alt_text
        "#{@level} membership badge"
      end
    end
  end
end
