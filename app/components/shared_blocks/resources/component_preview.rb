# frozen_string_literal: true

module SharedBlocks
  module Resources
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(SharedBlocks::Resources::Component.new)
      end
    end
  end
end
