# frozen_string_literal: true

module Admin
  module StravaRequestsChart
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

      private

      def status_series
        @status_series ||= build_series(StravaRequest::RESPONSE_STATUS_ENUM, :response_status)
      end

      def type_series
        @type_series ||= build_series(StravaRequest::REQUEST_TYPE_ENUM, :request_type)
      end

      def pie_columns
        @pie_columns ||= begin
          columns = [
            ["Response status", status_pie_counts, status_pie_colors],
            ["Request type", type_pie_counts, type_pie_colors]
          ]
          columns << ["By integration", integration_counts, nil] if @show_integration_chart
          columns
        end
      end

      def pie_chart_opts(colors, data)
        legend = (data.size > 4) ? false : {position: "bottom"}
        opts = {thousands: ",", library: {plugins: {legend:}}}
        opts[:colors] = colors if colors
        opts
      end

      def status_bar_colors
        status_series.map { |s| RESPONSE_STATUS_HEX_COLORS[s[:name].parameterize(separator: "_").to_sym] }
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
end
