# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Form
        class Component < ApplicationComponent
          # Sits under the full-width submit, so it's outside the <form> and its controls
          # reach the search with form: "Search_Form"
          renders_one :below_submit

          # Owner email only searches the organization's own registrations, so the field folds
          # away while search_all is checked - stacked or in the lg row, its gap taken back too
          EMAIL_FOLDS_WITH_SEARCH_ALL = "tw:transition-all tw:duration-200 tw:max-h-20 tw:min-w-0 " \
            "tw:search-all-checked:invisible tw:search-all-checked:opacity-0 tw:search-all-checked:max-h-0 " \
            "tw:search-all-checked:grow-0 tw:search-all-checked:p-0! tw:search-all-checked:border-0! " \
            "tw:search-all-checked:-mb-2 tw:lg:search-all-checked:mb-0 tw:lg:search-all-checked:-mr-2"

          def initialize(target_search_path:, interpreted_params:, heading:, submit_text:,
            target_frame: nil, settings_and_filters_component: nil)
            @target_search_path = target_search_path
            @interpreted_params = interpreted_params
            @target_frame = target_frame
            @settings_and_filters_component = settings_and_filters_component
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
              # The submit rebuilds the address bar from these fields, so the hidden ones
              # catch up with it first - a chart card collapsed since the last render
              {:turbo_frame => @target_frame, :turbo_action => "advance", :turbo => true,
               "search--form-target" => "form", :action => "search--form#syncHiddenFieldsFromUrl"}
            else
              {turbo: false}
            end
          end

          def serial_looks_like_not_a_serial?
            @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
          end

          def render_notes_field?
            @settings_and_filters_component&.notes_search?
          end

          def render_location_fields?
            @settings_and_filters_component.present?
          end

          def location_search_disabled?
            @settings_and_filters_component.location_search_disabled?
          end
        end
      end
    end
  end
end
