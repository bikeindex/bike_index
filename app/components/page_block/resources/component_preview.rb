# frozen_string_literal: true

module PageBlock
  module Resources
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(PageBlock::Resources::Component.new)
      end
    end
  end
end
