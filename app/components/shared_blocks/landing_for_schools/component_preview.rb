# frozen_string_literal: true

module SharedBlocks
  module LandingForSchools
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(SharedBlocks::LandingForSchools::Component.new)
      end
    end
  end
end
