# frozen_string_literal: true

module PeriodSelect
  class ComponentPreview < ApplicationComponentPreview
    # @!group Period Select Variants
    def default
      render(PeriodSelect::Component.new(
        period: "all",
        start_time: Time.current - 1.year,
        end_time: Time.current
      ))
    end

    def custom_selected
      render(PeriodSelect::Component.new(
        period: "custom",
        start_time: Time.current - 1.day,
        end_time: Time.current
      ))
    end

    def with_include_future
      render(PeriodSelect::Component.new(
        include_future: true,
        period: "next_week",
        start_time: Time.current,
        end_time: Time.current + 7.days
      ))
    end
    # @endgroup
  end
end
