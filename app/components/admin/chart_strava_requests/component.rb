# frozen_string_literal: true

module Admin::ChartStravaRequests
  class Component < ApplicationComponent
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
      enum.filter_map do |key, _|
        scoped = @collection.where(column => key)
        next if scoped.limit(1).blank?
        {name: key.to_s.humanize, data: chart.send(:time_range_counts, collection: scoped)}
      end
    end
  end
end
