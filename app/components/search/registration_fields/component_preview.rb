# frozen_string_literal: true

module Search::RegistrationFields
  class ComponentPreview < ApplicationComponentPreview
    def default
      interpreted_params = BikeSearchable.searchable_interpreted_params({})
      render(Search::RegistrationFields::Component.new(interpreted_params))
    end

    def chicago_tall_bike
      interpreted_params = BikeSearchable.searchable_interpreted_params({stolenness: "proximity",
        location: "Chicago, IL", query_items: ["v_9"]})

      render(Search::RegistrationFields::Component.new(interpreted_params))
    end
  end
end
