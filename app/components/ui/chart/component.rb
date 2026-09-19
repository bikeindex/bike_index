# frozen_string_literal: true

module UI
  module Chart
    class Component < ApplicationComponent
      # time_range_counts and the bucketing behind it, so a series assembled outside a
      # view buckets the way the views do
      extend GraphingHelper

      COLORS = %w[#3498db #DC2626 #D97706 #7C3AED #059669 #DB2777 #475569].freeze
      KINDS = %i[column line pie].freeze
      private_constant :KINDS

      # series: a grouped hash, an array of {name:, data:} series, or a path the chart
      # fetches its JSON from
      def initialize(series:, time_range: nil, kind: :column, colors: nil, stacked: false,
        prefix: nil, round: nil, height: nil, library: nil)
        raise ArgumentError, "kind must be one of #{KINDS.join(", ")}" unless KINDS.include?(kind)

        @series = series
        @time_range = time_range
        @kind = kind
        @colors = colors || COLORS
        @stacked = stacked
        @prefix = prefix
        @round = round
        @height = height
        @library = library
      end

      def call
        tag.div(data: {controller: "ui--chart"}) do
          helpers.public_send(:"#{@kind}_chart", chart_series, **chart_options)
        end
      end

      private

      # time_range_counts fills its own range, so this is for a series assembled some
      # other way -- and for an empty one, which chartkick draws as "No data"
      def chart_series
        return @series if @time_range.nil?

        case @series
        when Hash then empty_buckets.merge(@series)
        when Array then @series.map { it.merge(data: empty_buckets.merge(it[:data].to_h)) }
        else @series # a path, which the browser fetches the buckets for
        end
      end

      def empty_buckets
        @empty_buckets ||= self.class.empty_time_range_counts(@time_range)
      end

      def chart_options
        {thousands: ",", colors: chart_colors, stacked: @stacked,
         prefix: @prefix, round: @round, height: @height, library: @library}.compact
      end

      # Chartkick paints single-series column bars per-color from a flat array;
      # collapse to one so bars are uniform.
      def chart_colors
        (@kind == :column && @series.is_a?(Hash)) ? [@colors.first] : @colors
      end
    end
  end
end
