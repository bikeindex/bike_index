# frozen_string_literal: true

module Atoms
  module TimeRange
    class ComponentPreview < ApplicationComponentPreview
      def named_period
        render(Component.new(time_range: (Time.current - 1.week)..Time.current, period: "week"))
      end

      def custom_ending_now
        render(Component.new(time_range: (Time.current - 3.days)..Time.current, period: "custom"))
      end

      def custom_finished
        render(Component.new(time_range: (Time.current - 2.weeks)..(Time.current - 1.week), period: "custom"))
      end
    end
  end
end
