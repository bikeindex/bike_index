# frozen_string_literal: true

module SharedBlocks
  module SearchResults
    module BikeCard
      class ComponentPreview < ApplicationComponentPreview
        # @param search_all toggle
        # @param organized toggle "An org search, linking each card to its org page - off is the marketplace's"
        def default(search_all: false, organized: true)
          render_with_template(template: "shared_blocks/search_results/bike_card/component_preview/default",
            locals: {organization: (organization if organized), search_all:, component_class:,
                     bikes: SharedBlocks::SearchResults::BikeBox::ComponentPreview.vehicles + vehicle_types})
        end

        private

        # BikeListItem's preview renders the same bikes
        def component_class = Component

        def organization
          lookbook_organization || Organization.new(name: "Brakebills University", short_name: "Brakebills")
        end

        def vehicle_types
          [
            {id: 36, mnfg_name: "Co-Motion", frame_model: "Periscope", cycle_type: "tandem", color: "Red",
             created_at: 3.hours.ago},
            {id: 37, mnfg_name: "Christiania", frame_model: "Light", cycle_type: "cargo-trike", color: "Green",
             created_at: 1.day.ago},
            {id: 38, mnfg_name: "Segway", frame_model: "Ninebot Max", cycle_type: "e-scooter",
             propulsion_type: "throttle", color: "Black", created_at: 4.days.ago},
            {id: 39, mnfg_name: "Yuba", frame_model: "Spicy Curry", cycle_type: "cargo-rear",
             propulsion_type: "pedal-assist", color: "Yellow or Gold", created_at: 2.weeks.ago}
          ].map do |attrs|
            color = Color.find_by(name: attrs.delete(:color))
            Bike.new(serial_number: "PREVIEW#{attrs[:id]}", primary_frame_color: color, **attrs)
          end
        end
      end
    end
  end
end
