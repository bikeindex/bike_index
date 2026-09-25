# frozen_string_literal: true

module UI
  module Container
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def form = in_container(width: :form)

      def wide = in_container(width: :wide)

      def left_aligned = in_container(alignment: :left)
      # @!endgroup

      # Columns are the caller's: .twwiderow holds two, .twwiderow-3 three. Narrow the
      # preview to see the three go 2+1 and then drop to one column with the two
      def wide_with_rows
        {template: "ui/container/component_preview/wide_with_rows"}
      end

      private

      def in_container(width: :form, alignment: :center)
        {template: "ui/container/component_preview/in_container", locals: {width:, alignment:}}
      end
    end
  end
end
