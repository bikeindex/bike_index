# frozen_string_literal: true

module UI::Chart
  class Component < ApplicationComponent
    include ActionView::Helpers::TextHelper

    COLORS = %w[#0E8A16 #1D76DB #FBCA04 #D93F0B #5319E7 #B60205 #006B75].freeze

    class << self
      def time_range_counts(collection:, time_range:, column: "created_at")
        collection_grouped(collection:, column:, time_range:).count
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

    private

    def time_range_amounts(collection:, column: "created_at", amount_column: "amount_cents", time_range: nil, convert_to_dollars: false)
      result = self.class.send(:collection_grouped, collection:, column:, time_range: time_range || @time_range).sum(amount_column)

      return result unless convert_to_dollars

      result.map { |k, v| [k, (v.to_f / 100.00).round(2)] }.to_h
    end

    def time_range_length(time_range)
      time_range.last - time_range.first
    end

    def group_by_method(time_range)
      self.class.send(:group_by_method, time_range)
    end

    def group_by_format(time_range, group_period = nil)
      self.class.send(:group_by_format, time_range, group_period)
    end

    def humanized_time_range_column(time_range_column, return_value_for_all: false)
      return_value_for_all = true if @render_chart
      return nil unless return_value_for_all || !(@period == "all")

      humanized_text = time_range_column.to_s.gsub("_at", "").humanize.downcase
      return humanized_text.gsub("request", "requested") if time_range_column&.match?("request_at")
      return humanized_text.gsub("start", "starts") if time_range_column&.match?("start_at")
      return humanized_text.gsub("end", "ends") if time_range_column&.match?("end_at")
      return humanized_text.gsub("needs", "need") if time_range_column&.match?("needs_renewal_at")

      humanized_text
    end

    def humanized_time_range(time_range)
      return nil if @period == "all"

      unless @period == "custom"
        period_display = @period.match?("next_") ? @period.tr("_", " ") : "past #{@period}"
        return "in the #{period_display}"
      end
      group_period = group_by_method(time_range)
      precision_class = if group_period == :group_by_minute
        "preciseTimeSeconds"
      elsif group_period == :group_by_hour
        "preciseTime"
      else
        ""
      end
      end_html = if time_range.last > Time.current - 5.minutes
        "<em>now</em>"
      else
        "<em class=\"localizeTime #{precision_class}\">#{I18n.l(time_range.last, format: :convert_time)}</em>"
      end
      "<span>from <em class=\"localizeTime #{precision_class}\">#{I18n.l(time_range.first, format: :convert_time)}</em> to #{end_html}</span>"
    end

    def period_in_words(seconds)
      return "" if seconds.blank?

      seconds = seconds.to_i.abs
      if seconds >= 365.days
        pluralize((seconds / 31556952.0).round(1), "year")
      elsif seconds < 1.minute
        pluralize(seconds, "second")
      elsif seconds >= 1.minute && seconds < 1.hour
        pluralize((seconds / 60.0).round(1), "minute")
      elsif seconds >= 1.hour && seconds < 24.hours
        pluralize((seconds / 3600.0).round(1), "hour")
      elsif seconds >= 24.hours && seconds < 14.days
        pluralize((seconds / 86400.0).round(1), "day")
      else
        pluralize((seconds / 604800.0).round(1), "weeks")
      end.gsub(".0 ", " ")
    end

    def time_period_s(time_range)
      time_range.last - time_range.first
    end
  end
end
