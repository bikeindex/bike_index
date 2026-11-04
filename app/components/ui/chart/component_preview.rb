# frozen_string_literal: true

module UI
  module Chart
    class ComponentPreview < ApplicationComponentPreview
      def bikes_by_status
        time_range = 1.week.ago..::Time.current
        series = Bike::STATUS_ENUM.keys.filter_map do |status|
          scoped = Bike.where(status:, created_at: time_range)
          next if scoped.limit(1).blank?
          {name: Bike.status_humanized(status), data: UI::Chart::Component.time_range_counts(collection: scoped, time_range:)}
        end
        series = [{name: "No bikes", data: {}}] if series.empty?
        render(UI::Chart::Component.new(series:, time_range:, stacked: true))
      end

      def several_series
        render(UI::Chart::Component.new(series: several_series_data, stacked: true))
      end

      def skip_legend_counts
        render(UI::Chart::Component.new(series: several_series_data, stacked: true, skip_legend_counts: true))
      end

      def pie_with_prefix
        render(UI::Chart::Component.new(series: {"Donations" => 1234.5, "Stickers" => 20}, kind: :pie, prefix: "$", round: 2,
          library: {plugins: {legend: {position: "bottom"}}}))
      end

      private

      def several_series_data
        [{name: "Registered", data: {"Mon" => 1200, "Tue" => 34}},
          {name: "Stolen", data: {"Mon" => 3, "Tue" => 2}},
          {name: "Recovered", data: {"Mon" => 0, "Tue" => 0}}]
      end
    end
  end
end
