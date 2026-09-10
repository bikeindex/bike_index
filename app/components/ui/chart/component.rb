# frozen_string_literal: true

module UI
  module Chart
    class Component < ApplicationComponent
      # time_range_counts, time_range_amounts and the bucketing behind them, so callers
      # building a series outside a view have the same ones the views use
      extend GraphingHelper

      COLORS = %w[#3498db #DC2626 #D97706 #7C3AED #059669 #DB2777 #475569].freeze
      KINDS = %i[column line pie].freeze

      # series: a grouped hash, an array of {name:, data:} series, or a path the chart
      # fetches its JSON from. prefix, round, height and library are chartkick's, named
      # here so a typo raises rather than reaching the chart as an option it ignores.
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

      # Groupdate fills the range of the query it ran, so a series built any other way can
      # stop short of the period asked for, and an empty one draws chartkick's "No data"
      # rather than an empty chart
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

      # compact, rather than handing chartkick a nil for each one unset - it reads its own
      # defaults for the options it isn't given
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
