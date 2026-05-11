# frozen_string_literal: true

module PageBlock
  module HomepageForButtons
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(PageBlock::HomepageForButtons::Component.new)
      end
    end
  end
end
