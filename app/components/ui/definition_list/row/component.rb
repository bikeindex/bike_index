# frozen_string_literal: true

module UI
  module DefinitionList
    module Row
      class Component < ApplicationComponent
        def initialize(label:, value: nil, render_with_no_value: false, no_value_text: nil, full_width: false, time_localizer_settings: nil)
          @label = label
          @value = value
          @render_with_no_value = render_with_no_value
          @no_value_text = no_value_text
          @full_width = full_width

          # TODO: actually support originalTimeZone. When this is set currently, we show the timezone,
          # but it's still the user's timezone
          @include_time_zone = time_localizer_settings&.include?(:originalTimeZone) || false

          @time_localizer_classes = time_localizer_classes(time_localizer_settings)
        end

        def render?
          return true if @render_with_no_value

          @value.present? || content.present?
        end

        private

        def render_convertime?
          @value.present? && (@value.is_a?(::Time) || @value.is_a?(Date))
        end

        def no_value_content
          @no_value_text || translation(".no_value")
        end

        def wrapper_classes
          if @full_width
            "tw:col-span-full"
          else
            "tw:flex tw:items-baseline tw:justify-between tw:gap-x-4"
          end + " tw:pt-3 tw:leading-tight"
        end

        def dt_classes
          if @full_width
            "tw:pb-1"
          else
            "tw:flex-none"
          end + " tw:text-sm tw:leading-tight tw:opacity-65"
        end

        def dd_classes
          @full_width ? "tw:mb-0" : "tw:mb-0 tw:text-right"
        end

        def time_localizer_classes(time_localizer_settings)
          time_localizer_settings ||= []
          time_localizer_settings << "localizeTime"
          time_localizer_settings.join(" ")
        end
      end
    end
  end
end
