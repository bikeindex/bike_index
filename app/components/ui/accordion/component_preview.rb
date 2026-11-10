# frozen_string_literal: true

module UI
  module Accordion
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::Accordion::Component.new(items: [
          ["Is registering a bike free?", "Yes. Registering, searching, and reporting a theft are free for everyone."],
          ["Can I register a bike for someone else?", "Yes. They get an email to claim it, and it's theirs from then on."],
          ["What if I don't know the serial number?", "Register it as missing a serial, and add it whenever you find it."]
        ]))
      end
    end
  end
end
