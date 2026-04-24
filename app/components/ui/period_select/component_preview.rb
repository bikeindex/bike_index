# frozen_string_literal: true

module UI
  module PeriodSelect
    class ComponentPreview < ApplicationComponentPreview
      # @!group Period Select Variants
      def default
        render(UI::PeriodSelect::Component.new(
          period: "all",
          start_time: ::Time.current - 1.year,
          end_time: ::Time.current
        ))
      end

      def custom_selected
        render(UI::PeriodSelect::Component.new(
          period: "custom",
          start_time: ::Time.current - 1.day,
          end_time: ::Time.current
        ))
      end

      def with_include_future
        render(UI::PeriodSelect::Component.new(
          include_future: true,
          period: "next_week",
          start_time: ::Time.current,
          end_time: ::Time.current + 7.days
        ))
      end
      # @endgroup
    end
  end
end
