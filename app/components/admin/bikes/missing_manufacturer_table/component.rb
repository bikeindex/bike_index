# frozen_string_literal: true

module Admin
  module Bikes
    module MissingManufacturerTable
      # The bikes whose manufacturer is Other, with a checkbox each so a batch of them can
      # be reassigned to one manufacturer.
      class Component < ApplicationComponent
        def initialize(bikes:, index:, searched_other_name: nil)
          @bikes = bikes
          @index = index
          @searched_other_name = searched_other_name
        end

        private

        # The header cell checks and unchecks every row, through table-multi-checkbox on
        # the form this table sits in
        def toggle_all_button
          tag.button(check_mark, type: "button", title: "Toggle all checked",
            class: "twlink tw:cursor-pointer tw:border-0 tw:bg-transparent tw:p-0",
            aria: {label: "Toggle all checked"},
            data: {action: "click->table-multi-checkbox#toggleAll"})
        end

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
