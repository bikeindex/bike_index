# frozen_string_literal: true

module SharedBlocks
  module SystemColorScheme
    class Component < ApplicationComponent
      def initialize(color_scheme:)
        @color_scheme = color_scheme
      end

      def render? = @color_scheme == "system"
    end
  end
end
