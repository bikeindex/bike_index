# frozen_string_literal: true

module PageBlock::HomepageTop
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(PageBlock::HomepageTop::Component.new())
    end
  end
end
