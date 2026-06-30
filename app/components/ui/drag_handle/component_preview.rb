# frozen_string_literal: true

module UI
  module DragHandle
    class ComponentPreview < ApplicationComponentPreview
      # The grip in a sortable list -- one handle per row, registered as the
      # owning controller's "handle" target.
      def default
        {template: "ui/drag_handle/component_preview/default"}
      end

      # @label hyphenated controller (dasherizes the target key)
      def hyphenated_controller
        render(UI::DragHandle::Component.new(controller: "bullet-editors"))
      end

      # @label with extra classes appended
      def with_html_class
        render(UI::DragHandle::Component.new(controller: "sortable", html_class: "tw:pt-2"))
      end
    end
  end
end
