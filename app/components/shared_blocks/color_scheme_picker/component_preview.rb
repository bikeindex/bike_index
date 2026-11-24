# frozen_string_literal: true

module SharedBlocks
  module ColorSchemePicker
    class ComponentPreview < ApplicationComponentPreview
      # @!group Color scheme picker
      def default
        render(SharedBlocks::ColorSchemePicker::Component.new(color_scheme: "system"))
      end

      def compact
        render(SharedBlocks::ColorSchemePicker::Component.new(color_scheme: "dark", compact: true))
      end
      # @endgroup
    end
  end
end
