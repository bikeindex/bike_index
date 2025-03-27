# frozen_string_literal: true

module Search::TargetingFields
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::TargetingFields::Component.new(distance:, location:, stolenness:))
    end
  end
end
