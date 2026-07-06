# frozen_string_literal: true

module UI
  module ShortId
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::ShortId::Component.new(short_id: "r/21J-HW"))
      end

      # @label short (decimal) id
      def decimal
        render(UI::ShortId::Component.new(short_id: "r/36"))
      end

      # @label with extra classes appended
      def with_html_class
        render(UI::ShortId::Component.new(short_id: "r/21J-HW", html_class: "tw:text-base"))
      end
    end
  end
end
