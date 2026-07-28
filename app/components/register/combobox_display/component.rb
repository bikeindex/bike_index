# frozen_string_literal: true

module Register
  module ComboboxDisplay
    # Wraps a combobox with the overlay register--combobox-display paints the
    # selected option's rich content onto (see the controller).
    class Component < ApplicationComponent
      OVERLAY_CLASSES = "tw:pointer-events-none tw:absolute tw:hidden tw:truncate tw:text-gray-900 tw:dark:text-gray-200"

      def initialize(html_class: nil)
        @html_class = html_class
      end

      def call
        tag.div(class: ["tw:relative", @html_class].compact.join(" "),
          data: {controller: "register--combobox-display"}) do
          content + tag.div("", class: OVERLAY_CLASSES, data: {"register--combobox-display-target": "overlay"})
        end
      end
    end
  end
end
