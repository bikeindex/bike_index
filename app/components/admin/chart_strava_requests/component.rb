# frozen_string_literal: true

module Admin::ChartStravaRequests
  class Component < ApplicationComponent
    def initialize(collection:, time_range:, time_range_column: "created_at", show_integration_chart: true)
      @collection = collection
      @time_range = time_range
      @time_range_column = time_range_column
      @show_integration_chart = show_integration_chart
    end

    def call
      parts = [
        tag.h4("By response status", class: "mt-4"),
        render(UI::Chart::Component.new(series: status_series, time_range: @time_range, stacked: true)),
        tag.h4("By request type", class: "mt-4"),
        render(UI::Chart::Component.new(series: type_series, time_range: @time_range, stacked: true))
      ]
      if @show_integration_chart
        parts << tag.h4("By integration", class: "mt-4")
        parts << helpers.pie_chart(integration_counts)
      end
      safe_join(parts)
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
        {name: key.to_s.humanize, data: UI::Chart::Component.time_range_counts(collection: scoped, time_range: @time_range, column: @time_range_column)}
      end
    end

    def integration_counts
      counts = @collection.group(:strava_integration_id).count.sort_by { |_, count| -count }
      integration_ids = counts.map(&:first)
      emails = StravaIntegration.where(id: integration_ids).joins(:user).pluck(:id, "users.email").to_h
      counts.to_h do |integration_id, count|
        email = emails[integration_id]
        label = email ? "#{email} (id: #{integration_id})" : "user deleted (id: #{integration_id})"
        [label, count]
      end
    end
  end
end
