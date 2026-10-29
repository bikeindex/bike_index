# frozen_string_literal: true

module UI
  module DragHandle
    # Grip for a drag controller - sortable_controller (and subclasses), ui--table-column-order.
    # `controller` is its Stimulus identifier, so the handle registers as its "handle" target.
    class Component < ApplicationComponent
      def initialize(controller:, html_class: nil)
        @controller = controller
        @html_class = html_class
      end

      def call
        content_tag(:span, "⠿",
          aria: {hidden: true},
          style: "touch-action:none",
          class: ["tw:cursor-grab tw:select-none tw:text-gray-400", @html_class].compact.join(" "),
          data: {"#{@controller.tr("-", "_")}_target": "handle"})
      end
    end
  end
end
