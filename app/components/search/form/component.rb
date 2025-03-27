# frozen_string_literal: true

module Search::Form
  class Component < ApplicationComponent
    def initialize(target_search_path:, interpreted_params:, selected_query_items_options:)
      @target_search_path = target_search_path
      @interpreted_params = interpreted_params
      @selected_query_items_options = selected_query_items_options
    end

    private

    def query
      @interpreted_params[:query] # might be more complicated someday
    end

    def distance_value
      @interpreted_params[:distance] || 100
    end

    def include_stolenness?
      true # will be false for versions and marketplace
    end

    def include_location_search?
      true # false when bike versions or non-stolen
    end

    def location_fields_hidden?
      @interpreted_params[:stolenness] == "proximity" # also true for marketplace
    end

    def render_serial_field?
      true # false if bike versions, or marketplace
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end

    def stolenness_radio_classes
      "tw:w-4 tw:h-4 tw:text-blue-600 tw:bg-gray-100 tw:border-gray-300 tw:focus:ring-blue-500 " \
      ":tw:dark:focus:ring-blue-600 tw:dark:ring-offset-gray-700 tw:dark:focus:ring-offset-gray-700 " \
      "tw:focus:ring-2 tw:dark:bg-gray-600 tw:dark:border-gray-500"
    end

    def stolenness_radio_item(stolenness, skip_count: false, skip_li_border: false)
      li_class = "tw:w-full tw:has-checked:bg-gray-100 tw:has-checked:dark:bg-gray-700 "
      unless skip_li_border
        li_class += "tw:border-b tw:sm:border-b-0 tw:sm:border-r tw:border-inherit"
      end
      content_tag(:li, class: li_class) do
        content_tag(:div, class: "tw:flex tw:items-center tw:ps-3") do
          concat(radio_button_tag(:stolenness, stolenness,
            @interpreted_params[:stolenness] == stolenness,
            class: stolenness_radio_classes))

          concat(label_tag("stolenness_#{stolenness}", class: "tw:w-full tw:py-3 tw:ms-2 tw:cursor-pointer") do
            concat(translation(".stolenness_#{stolenness}"))
            concat(content_tag(:span, "", class: "count")) unless skip_count
          end)
        end
      end
    end
  end
end
