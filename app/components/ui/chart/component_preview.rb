# frozen_string_literal: true

module UI::Chart
  class ComponentPreview < ApplicationComponentPreview
    def bikes_by_status
      time_range = 1.week.ago..Time.current
      series = Bike::STATUS_ENUM.keys.filter_map do |status|
        scoped = Bike.where(status:, created_at: time_range)
        next if scoped.limit(1).blank?
        {name: Bike.status_humanized(status), data: UI::Chart::Component.time_range_counts(collection: scoped, time_range:)}
      end
      series = [{name: "No bikes", data: {}}] if series.empty?
      render(UI::Chart::Component.new(series:, time_range:, stacked: true))
    end
  end
end
