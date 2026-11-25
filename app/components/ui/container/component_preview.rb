# frozen_string_literal: true

module UI
  module Container
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def default = in_container

      def wide = in_container(width: :wide)

      def left_aligned = in_container(alignment: :left)
      # @!endgroup

      private

      def in_container(**options)
        {template: "ui/container/component_preview/in_container", locals: {options:}}
      end
    end
  end
end
