# frozen_string_literal: true

module PageBlock::HomepageForButtons
  class ComponentPreview < ApplicationComponentPreview
    # @display redesign_2025_stylesheet true
    def default
      render(PageBlock::HomepageForButtons::Component.new)
    end
  end
end
