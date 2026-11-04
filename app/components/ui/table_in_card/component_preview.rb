# frozen_string_literal: true

module UI
  module TableInCard
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # Narrower than its columns, the first stays put while the rest scroll under it
      def default
        render_with_template(template: "ui/table_in_card/component_preview/cryptids", locals: {selection: false})
      end

      # Shift-click a checkbox to give every one since the last clicked its state
      def selection
        render_with_template(template: "ui/table_in_card/component_preview/cryptids", locals: {selection: true})
      end

      # @!endgroup
    end
  end
end
