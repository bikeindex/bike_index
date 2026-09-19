# frozen_string_literal: true

module UI
  module TimeRange
    class Component < ApplicationComponent
      def initialize(time_range:, period:)
        @time_range = time_range
        @period = period
      end

      def call
        return period_phrase unless @period == "custom"

        content_tag(:span) do
          safe_join([translation(".from"), tag.em(render(endpoint(@time_range.first))),
            translation(".to"), tag.em(ends_now? ? translation(".now") : render(endpoint(@time_range.last)))], " ")
        end
      end

      private

      def render? = @period.present? && @period != "all"

      # A whole sentence per period, so a locale can inflect it
      def period_phrase
        case @period
        when "hour" then translation(".in_the_past_hour")
        when "day" then translation(".in_the_past_day")
        when "week" then translation(".in_the_past_week")
        when "month" then translation(".in_the_past_month")
        when "year" then translation(".in_the_past_year")
        when "next_week" then translation(".in_the_next_week")
        when "next_month" then translation(".in_the_next_month")
        end
      end

      def endpoint(time)
        UI::Time::Component.new(time:, format: time_format)
      end

      def time_format
        length = @time_range.last - @time_range.first
        if length <= 1.hour then :localize_time_precise_seconds
        elsif length < 5.days then :localize_time_precise
        end
      end

      # Anything this recent was "now" when the range was built
      def ends_now? = @time_range.last > ::Time.current - 5.minutes
    end
  end
end
