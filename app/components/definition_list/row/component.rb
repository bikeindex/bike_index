# frozen_string_literal: true

module DefinitionList::Row
  class Component < ApplicationComponent
    def initialize(label:, value: nil, render_with_no_value: false, full_width: false, time_localizer_settings: nil)
      @label = label
      @value = value
      @render_with_no_value = render_with_no_value
      @full_width = full_width

      # TODO: actually support originalTimeZone. We add the timezone, but it's currently the user's timezone
      @include_time_zone = time_localizer_settings&.include?(:originalTimeZone) || false

      @time_localizer_classes = time_localizer_classes(time_localizer_settings)
    end

    def render?
      return true if @render_with_no_value

      @value.present?
    end

    private

    def render_convertime?
      @value.present? && (@value.is_a?(Time) || @value.is_a?(Date))
    end

    def no_value_content
      translation(".no_value")
    end

    def wrapper_classes
      if @full_width
        "tw:col-span-full"
      else
        "tw:items-center tw:@sm:flex tw:@sm:gap-x-2 tw:@sm:pt-2"
      end + " tw:pt-3 tw:leading-tight"
    end

    def dt_classes
      if @full_width
        ""
      else
        "tw:@sm:text-right tw:@sm:w-1/4 tw:min-w-[100px]"
      end + " tw:text-sm tw:leading-none tw:opacity-65 tw:font-bold!"
    end

    def time_localizer_classes(time_localizer_settings)
      time_localizer_settings ||= []
      time_localizer_settings << "convertTime"
      time_localizer_settings.join(" ")
    end
  end
end
