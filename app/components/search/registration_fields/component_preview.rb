# frozen_string_literal: true

module Search::RegistrationFields
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::RegistrationFields::Component.new(stolenness: "stolen"))
    end

    def chicago_tall_bike
      render(Search::RegistrationFields::Component.new(stolenness: "proximity",
        location: "Chicago, IL"))
    end
  end
end
