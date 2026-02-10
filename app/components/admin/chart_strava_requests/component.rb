# frozen_string_literal: true

module Admin::ChartStravaRequests
  class Component < ApplicationComponent
    COLORS = UI::Chart::Component::COLORS

    def initialize(collection:, time_range:)
      @collection = collection
      @time_range = time_range
    end

    private

    def status_series
      @status_series ||= build_series(StravaRequest::RESPONSE_STATUS_ENUM, :response_status)
    end

    def type_series
      @type_series ||= build_series(StravaRequest::REQUEST_TYPE_ENUM, :request_type)
    end

    def chart
      @chart ||= UI::Chart::Component.new(series: [], time_range: @time_range)
    end

    def build_series(enum, column)
      enum.filter_map.with_index do |(key, _), i|
        scoped = @collection.where(column => key)
        next if scoped.limit(1).blank?
        {name: key.to_s.humanize, data: chart.time_range_counts(collection: scoped), color: COLORS[i]}
      end
    end
  end
end
