# frozen_string_literal: true

module SearchResults::BikeBox
  class ComponentPreview < ApplicationComponentPreview
    # TODO: pass bikes from here, rather than in the template :/
    # Other previews to include:
    # - every status (stolen, abandoned, impounded, parking)
    # - no photo, minimal information
    # - serial user_hidden

    def default
      {template: "search/bike_box/component_preview/default"}
    end
  end
end
