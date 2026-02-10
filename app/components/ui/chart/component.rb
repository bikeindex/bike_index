# frozen_string_literal: true

module UI::Chart
  class Component < ApplicationComponent
    COLORS = %w[#3498db #DC2626 #D97706 #7C3AED #059669 #DB2777 #475569].freeze

    class << self
      def time_range_counts(collection:, time_range:, column: "created_at")
        collection_grouped(collection:, column:, time_range:).count
      end

      def time_range_amounts(collection:, time_range:, column: "created_at", amount_column: "amount_cents", convert_to_dollars: false)
        result = collection_grouped(collection:, column:, time_range:).sum(amount_column)
        return result unless convert_to_dollars

        result.transform_values { |v| (v.to_f / 100.00).round(2) }
      end

      private

      def collection_grouped(collection:, time_range:, column: "created_at")
        collection.send(
          group_by_method(time_range),
          column,
          range: time_range,
          format: group_by_format(time_range)
        )
      end

      def group_by_method(time_range)
        period_s = time_range.last - time_range.first
        if period_s < 3601 # 1.hour + 1 second
          :group_by_minute
        elsif period_s < 5.days
          :group_by_hour
        elsif period_s < 5_000_000 # around 60 days
          :group_by_day
        elsif period_s < 31449600 # 364 days (52 weeks)
          :group_by_week
        else
          :group_by_month
        end
      end

      def group_by_format(time_range, group_period = nil)
        period_s = time_range.last - time_range.first
        group_period ||= group_by_method(time_range)
        if group_period == :group_by_minute
          "%l:%M %p"
        elsif group_period == :group_by_hour
          "%a%l %p"
        elsif group_period == :group_by_month
          "%Y-%-m"
        elsif group_period == :group_by_day && (period_s < 10.days)
          "%a %-m-%-d"
        else
          "%Y-%-m-%-d"
        end
      end
    end

    def initialize(series:, time_range:, stacked: false, thousands: ",", colors: nil)
      @series = series
      @time_range = time_range
      @stacked = stacked
      @thousands = thousands
      @colors = colors || COLORS
    end

    def call
      helpers.column_chart @series, stacked: @stacked, thousands: @thousands, colors: @colors
    end
  end
end
