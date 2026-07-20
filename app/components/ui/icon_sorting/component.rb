# frozen_string_literal: true

module UI
  module IconSorting
    class Component < ApplicationComponent
      ARROWS = {
        "asc" => "↑",
        "desc" => "↓"
      }.freeze

      def initialize(direction: "desc")
        @arrow = ARROWS.fetch(direction.to_s, "↓")
      end

      def call
        @arrow.html_safe
      end
    end
  end
end
