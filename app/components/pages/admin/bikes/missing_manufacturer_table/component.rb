# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module MissingManufacturerTable
        # The bikes whose manufacturer is Other, with a checkbox each so a batch of them can
        # be reassigned to one manufacturer.
        class Component < ApplicationComponent
          COLUMNS = {info_cell: "Info", created_by_cell: "Created by"}.freeze

          def initialize(bikes:, index:, searched_other_name: nil)
            @bikes = bikes
            @index = index
            @searched_other_name = searched_other_name
          end

          private

          def description(bike)
            [bike.year, bike.frame_model, ("(#{bike.type})" unless bike.type == "bike")]
              .select(&:present?).join(" ")
          end

          def other_name_search_path(bike)
            url_for(@index.sortable_search_params.merge(search_other_name: bike.manufacturer_other))
          end

          # A paint with no color is what an admin would go and set, so it links to the paint
          def unmatched_paint(bike)
            bike.paint if bike.paint.present? && bike.paint.color_id.blank?
          end
        end
      end
    end
  end
end
