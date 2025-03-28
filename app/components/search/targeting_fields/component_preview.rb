# frozen_string_literal: true

module Search::TargetingFields
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::TargetingFields::Component.new(interpreted_params))
    end

    private

    def interpreted_params
      BikeSearchable.searchable_interpreted_params({})
    end
  end
end
