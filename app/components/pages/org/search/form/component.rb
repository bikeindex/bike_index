# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Form
        class Component < ApplicationComponent
          # Sits under the full-width submit, so it's outside the <form> and its controls
          # reach the search with form: "Search_Form"
          renders_one :below_submit

          def initialize(target_search_path:, interpreted_params:, target_frame: nil, skip_serial_field: false,
            filters_component: nil, notes_search: false, heading: nil, submit_text: nil)
            @target_search_path = target_search_path
            @interpreted_params = interpreted_params
            @target_frame = target_frame
            @skip_serial_field = skip_serial_field
            @filters_component = filters_component
            @notes_search = notes_search
            # heading turns the form into a card, with the submit spanning it rather than
            # sitting in the fields row as an icon
            @heading = heading
            @submit_text = submit_text
            @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
          end

          private

          def card?
            @heading.present?
          end

          def turbo?
            @target_frame.present?
          end

          def form_data
            if turbo?
              {:turbo_frame => @target_frame, :turbo_action => "advance",
               :turbo => true, "search--form-target" => "form"}
            else
              {turbo: false}
            end
          end

          def render_serial_field?
            !@skip_serial_field
          end

          def serial_looks_like_not_a_serial?
            @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
          end

          def render_notes_field?
            @notes_search
          end

          def card_classes
            "tw:rounded-xl tw:border tw:border-gray-200 tw:bg-white tw:p-4 tw:dark:border-gray-700 tw:dark:bg-gray-800"
          end
        end
      end
    end
  end
end
