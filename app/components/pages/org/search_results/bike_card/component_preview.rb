# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module BikeCard
        class ComponentPreview < ApplicationComponentPreview
          # @param search_all toggle
          def default(search_all: false)
            organization = lookbook_organization || Organization.new(name: "Brakebills University", short_name: "Brakebills")
            render_with_template(template: "pages/org/search_results/bike_card/component_preview/default",
              locals: {organization:, search_all:, bikes: Pages::SearchResults::BikeBox::ComponentPreview.vehicles + vehicle_types})
          end

          private

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
end
