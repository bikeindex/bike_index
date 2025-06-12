# frozen_string_literal: true

module Search::KindSelectFields
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::KindSelectFields::Component.new(stolenness: "stolen"))
    end

    def chicago_tall_bike
      render(Search::KindSelectFields::Component.new(stolenness: "proximity",
        location: "Chicago, IL"))
    end
  end
end
