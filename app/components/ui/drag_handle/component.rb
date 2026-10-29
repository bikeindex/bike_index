# frozen_string_literal: true

module UI
  module DragHandle
    # Grip for a drag controller - sortable_controller (and subclasses), ui--table-column-order.
    # `controller` is its Stimulus identifier, so the handle registers as its "handle" target and
    # its arrow keys call the controller's moveByKey. `label` names what it moves.
    class Component < ApplicationComponent
      def initialize(controller:, label:, html_class: nil)
        @controller = controller
        @label = label
        @html_class = html_class
      end

      def call
        content_tag(:button, "⠿",
          type: "button",
          aria: {label: translation(".move", name: @label)},
          style: "touch-action:none",
          class: ["tw:cursor-grab tw:select-none tw:text-gray-400", @html_class].compact.join(" "),
          data: {"#{@controller.tr("-", "_")}_target": "handle", action: "keydown->#{@controller}#moveByKey",
                 moved_message: translation(".moved", position: "%{position}", count: "%{count}")})
      end
    end
  end
end
