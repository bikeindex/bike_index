# frozen_string_literal: true

module BikeListBlock
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(BikeListBlock::Component.new)
    end
  end
end
