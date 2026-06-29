# frozen_string_literal: true

module UI
  module DragHandle
    # Grip for sortable_controller (and subclasses). `controller` is the Stimulus identifier
    # that owns the list, so the handle registers as that controller's "handle" target.
    class Component < ApplicationComponent
      def initialize(controller:, html_class: nil)
        @controller = controller
        @html_class = html_class
      end

      def call
        content_tag(:span, "⠿",
          draggable: "true",
          aria: {hidden: true},
          class: ["tw:cursor-grab tw:select-none tw:text-gray-400", @html_class].compact.join(" "),
          data: {"#{@controller.tr("-", "_")}_target": "handle"})
      end
    end
  end
end
