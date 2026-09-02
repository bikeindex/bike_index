# frozen_string_literal: true

module SharedBlocks
  module LandingForLawEnforcement
    class ComponentPreview < ApplicationComponentPreview
      # @display kelsey_stylesheet true
      def default
        render(SharedBlocks::LandingForLawEnforcement::Component.new)
      end
    end
  end
end
