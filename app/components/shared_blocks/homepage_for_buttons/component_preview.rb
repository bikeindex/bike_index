# frozen_string_literal: true

module SharedBlocks
  module HomepageForButtons
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(SharedBlocks::HomepageForButtons::Component.new)
      end
    end
  end
end
