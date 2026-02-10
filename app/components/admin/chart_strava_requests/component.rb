# frozen_string_literal: true

module Admin::ChartStravaRequests
  class Component < ApplicationComponent
    include GraphingHelper

    COLORS = %w[#0E8A16 #1D76DB #FBCA04 #D93F0B #5319E7 #B60205 #006B75].freeze

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

    def status_colors
      status_series.map { |s| s[:color] }
    end

    def type_colors
      type_series.map { |s| s[:color] }
    end

    def build_series(enum, column)
      enum.filter_map.with_index do |(key, _), i|
        scoped = @collection.where(column => key)
        next if scoped.limit(1).blank?
        {name: key.to_s.humanize, data: time_range_counts(collection: scoped), color: COLORS[i]}
      end
    end
  end
end
