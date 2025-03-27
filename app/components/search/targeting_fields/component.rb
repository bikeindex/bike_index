# frozen_string_literal: true

module Search::TargetingFields
  class Component < ApplicationComponent
    DEFAULT_DISTANCE = 100
    MAX_DISTANCE = 2_000 # IDK, seems reasonable

    def initialize(stolenness:, distance: nil, location: nil)
      @distance = distance.present? ? distance.to_i : DEFAULT_DISTANCE
      @distance.clamp(1, MAX_DISTANCE)

      @location = location
      @stolenness = stolenness
    end

    private

    def include_stolenness?
      true # will be false for versions and marketplace
    end

    def location_fields_hidden?
      @stolenness == "proximity" # also true for marketplace
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
            @stolenness == stolenness,
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
