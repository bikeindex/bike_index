# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Form
        class Component < ApplicationComponent
          # Sits under the full-width submit, so it's outside the <form> and its controls
          # reach the search with form: "Search_Form"
          renders_one :below_submit

          def initialize(target_search_path:, interpreted_params:, heading:, submit_text:,
            target_frame: nil, filters_component: nil)
            @target_search_path = target_search_path
            @interpreted_params = interpreted_params
            @target_frame = target_frame
            @filters_component = filters_component
            @heading = heading
            @submit_text = submit_text
            @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
          end

          private

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

          def serial_looks_like_not_a_serial?
            @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
          end

          def render_notes_field?
            @filters_component&.notes_search?
          end
        end
      end
    end
  end
end
