# frozen_string_literal: true

module UI
  module TableInCard
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # Narrower than its columns, so the first stays put while the rest scroll under it
      def default
        render_with_template(template: "ui/table_in_card/component_preview/default", locals: {records: UI::Table::ComponentPreview::SAMPLE_RECORDS})
      end

      # Shift-click a checkbox to give every one since the last clicked its state
      def selection
        render_with_template(template: "ui/table_in_card/component_preview/selection", locals: {records: UI::Table::ComponentPreview::SAMPLE_RECORDS})
      end

      # @!endgroup
    end
  end
end
