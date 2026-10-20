# frozen_string_literal: true

module UI
  module CopyableCode
    class Component < ApplicationComponent
      strip_trailing_whitespace

      def initialize(value:, label:)
        @value = value
        @label = label
      end
    end
  end
end
