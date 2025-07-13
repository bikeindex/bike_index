# frozen_string_literal: true

module SearchResults::BikeBox
  class ComponentPreview < ApplicationComponentPreview
    def self.vehicles
      built_bike = Bike.new(
        id: 35,
        serial_number: "XXX999 999xxxx",
        mnfg_name: "Humble Frameworks",
        year: "2015",
        primary_frame_color_id: Color.where(name: "Purple").first_or_create,
        frame_model: "self titled",
        frame_material: :steel,
        cycle_type: :bike,
        thumb_path:
          "https://files.bikeindex.org/uploads/Pu/395980/small_D3C6B1AF-F1FC-4BAA-BD39-9C107871FCAE.jpeg"
      )
      [
        built_bike,
        Bike.status_stolen.first,
        Bike.status_impounded.first,
        MarketplaceListing.for_sale.last&.item
      ].compact
    end

    # TODO: pass bikes from here, rather than in the template :/
    # Other previews to include:
    # - every status (stolen, abandoned, impounded, parking)
    # - no photo, minimal information
    # - serial user_hidden

    def default
      {template: "search_results/bike_box/component_preview/default"}
    end
  end
end
