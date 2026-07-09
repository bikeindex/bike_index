# frozen_string_literal: true

module UI
  module ColorSwatch
    class ComponentPreview < ApplicationComponentPreview
      def black
        render(UI::ColorSwatch::Component.new(display: "#000", name: "Black"))
      end

      def blue
        render(UI::ColorSwatch::Component.new(display: "#386ed2", name: "Blue"))
      end

      # The display-less cover-up color renders the multicolor blend
      def cover_up
        render(UI::ColorSwatch::Component.new(name: Color::COVER_UP_NAME))
      end
    end
  end
end
