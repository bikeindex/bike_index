# frozen_string_literal: true

module Atoms
  module TimeRange
    class Component < ApplicationComponent
      # The localizer reads its precision off the class list, so a range bucketed
      # by minute has to render seconds for its endpoints to differ
      TIME_FORMATS = {group_by_minute: :localize_time_precise_seconds,
                      group_by_hour: :localize_time_precise}.freeze

      def initialize(time_range:, period:)
        @time_range = time_range
        @period = period
      end

      private

      def render? = @period.present? && @period != "all"

      def custom? = @period == "custom"

      def period_phrase
        return translation(".in_the_next", period: @period.delete_prefix("next_")) if @period.match?("next_")

        translation(".in_the_past", period: @period)
      end

      def endpoint(time)
        UI::Time::Component.new(time:, format: TIME_FORMATS[helpers.group_by_method(@time_range)])
      end

      # Anything this recent was "now" when the range was built
      def ends_now? = @time_range.last > ::Time.current - 5.minutes
    end
  end
end
