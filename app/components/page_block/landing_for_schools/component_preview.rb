# frozen_string_literal: true

module PageBlock::LandingForSchools
  class ComponentPreview < ApplicationComponentPreview
    # @display kelsey_stylesheet true
    def default
      render(PageBlock::LandingForSchools::Component.new)
    end
  end
end
