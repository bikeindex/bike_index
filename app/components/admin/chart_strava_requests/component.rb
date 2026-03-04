# frozen_string_literal: true

module Admin::ChartStravaRequests
  class Component < ApplicationComponent
    RESPONSE_STATUS_BADGE_COLORS = {
      pending: :cyan,
      success: :success,
      rate_limited: :warning,
      error: :error,
      skipped: :purple,
      integration_deleted: :gray,
      token_refresh_failed: :rose,
      insufficient_token_privileges: :orange
    }.freeze

    RESPONSE_STATUS_HEX_COLORS = {
      pending: "#22d3ee",
      success: "#10b981",
      error: "#DC2626",
      rate_limited: "#f59e0b",
      token_refresh_failed: "#fb7185",
      integration_deleted: "#9ca3af",
      skipped: "#a855f7",
      insufficient_token_privileges: "#fb923c"
    }.freeze

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

      pie_columns = []
      pie_columns << pie_column("Response status", status_pie_counts, status_pie_colors)
      pie_columns << pie_column("Request type", type_pie_counts, type_pie_colors)
      if @show_integration_chart
        pie_columns << pie_column("By integration", integration_counts)
      end
      parts << tag.div(safe_join(pie_columns), class: "tw:grid tw:grid-cols-1 tw:md:grid-cols-#{pie_columns.size} tw:gap-4 tw:mt-4")

      safe_join(parts)
    end

    private

    def pie_column(title, data, colors = nil)
      chart_opts = {thousands: ",", library: {plugins: {legend: {position: "bottom"}}}}
      chart_opts[:colors] = colors if colors
      tag.div(
        safe_join([
          tag.h4(title),
          helpers.pie_chart(data, **chart_opts)
        ])
      )
    end

    def status_pie_counts
      @status_pie_counts ||= build_pie_counts(StravaRequest::RESPONSE_STATUS_ENUM, :response_status)
    end

    def status_pie_colors
      status_pie_counts.keys.map { |key| RESPONSE_STATUS_HEX_COLORS[key.parameterize(separator: "_").to_sym] }
    end

    def type_pie_counts
      @type_pie_counts ||= build_pie_counts(StravaRequest::REQUEST_TYPE_ENUM, :request_type)
    end

    def type_pie_colors
      type_pie_counts.keys.each_with_index.map { |_, i| UI::Chart::Component::COLORS[i % UI::Chart::Component::COLORS.size] }
    end

    def build_pie_counts(enum, column)
      enum.each_with_object({}) do |(key, _), hash|
        count = @collection.where(column => key).count
        hash[key.to_s.humanize] = count if count > 0
      end
    end

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
