# frozen_string_literal: true

module Atoms
  module CopyableCode
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def default
        render(Atoms::CopyableCode::Component.new(value: "r/21J-HW", label: "Copy ID"))
      end

      # @label too narrow for the value: scrolls, with the copy button over its right edge
      def overflowing
        {template: "atoms/copyable_code/component_preview/overflowing"}
      end
      # @!endgroup
    end
  end
end
