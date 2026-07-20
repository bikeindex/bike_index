# frozen_string_literal: true

module UI
  module IconSorting
    class Component < ApplicationComponent
      DIRECTIONS = {
        "asc" => :up,
        "desc" => :down
      }.freeze

      def initialize(direction: "desc", html_class: nil)
        @direction = DIRECTIONS.fetch(direction.to_s, :down)
        @html_class = html_class
      end
    end
  end
end
