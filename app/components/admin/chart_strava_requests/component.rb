# frozen_string_literal: true

module Admin::ChartStravaRequests
  class Component < ApplicationComponent
    def initialize(collection:, time_range:)
      @collection = collection
      @time_range = time_range
    end

    def call
      safe_join([
        tag.h4("By response status", class: "mt-4"),
        render(UI::Chart::Component.new(series: status_series, time_range: @time_range, stacked: true)),
        tag.h4("By request type", class: "mt-4"),
        render(UI::Chart::Component.new(series: type_series, time_range: @time_range, stacked: true))
      ])
    end

    private

    def status_series
      @status_series ||= build_series(StravaRequest::RESPONSE_STATUS_ENUM, :response_status)
    end

    def type_series
      @type_series ||= build_series(StravaRequest::REQUEST_TYPE_ENUM, :request_type)
    end

    def build_series(enum, column)
      enum.filter_map do |key, _|
        scoped = @collection.where(column => key)
        next if scoped.limit(1).blank?
        {name: key.to_s.humanize, data: UI::Chart::Component.time_range_counts(collection: scoped, time_range: @time_range)}
      end
    end
  end
end
