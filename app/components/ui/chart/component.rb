# frozen_string_literal: true

module UI
  module Chart
    class Component < ApplicationComponent
      # time_range_counts and the bucketing behind it, so a series assembled outside a
      # view buckets the way the views do
      extend GraphingHelper

      COLORS = %w[#3498db #DC2626 #7C3AED #D97706 #059669 #DB2777 #475569 #0891B2 #65A30D #EA580C].freeze
      KINDS = %i[column line pie].freeze
      private_constant :KINDS

      # series: a grouped hash, an array of {name:, data:} series, or a path the chart
      # fetches its JSON from
      def initialize(series:, time_range: nil, kind: :column, colors: nil, stacked: false,
        prefix: nil, round: nil, height: "300px", library: nil)
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

      # The height is fixed so a legend comes out of the chart's, as Chart.js's own did
      def call
        tag.div(class: "tw:flex tw:flex-col tw:*:min-h-0", style: "height: #{@height}", data: {controller: "ui--chart"}) do
          safe_join([(legend if legend?), helpers.public_send(:"#{@kind}_chart", chart_series, **chart_options)])
        end
      end

      private

      # Filled in by ui--chart, since a series from a path has no totals until it's fetched
      def legend
        item = safe_join([tag.span(class: "tw:size-3 tw:border"), tag.span, " ", tag.span(class: "twless-strong tw:-ml-0.5 tw:text-xs")])
        safe_join([
          tag.div(class: class_names("tw:flex tw:shrink-0 tw:flex-wrap tw:justify-center tw:gap-x-5 tw:gap-y-1 tw:py-1",
            "tw:order-1": library_legend&.dig(:position) == "bottom"), data: {chart_legend: true}),
          tag.template(render(UI::Button::Component.new(text: item, color: :link_gray, html_class: "tw:text-sm tw:font-normal tw:no-underline")))
        ])
      end

      # A pie's legend names its slices, so it keeps one
      def legend?
        return false if library_legend == false

        @kind == :pie || !(@series.is_a?(Hash) || (@series.is_a?(Array) && @series.one?))
      end

      def library_legend = @library&.dig(:plugins, :legend)

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

      # Chartkick counts ids per view, and every frame response and Lookbook example is a
      # fresh one - so two on a page would both be chart-1, and draw into the first
      def chart_options
        {id: "chart-#{SecureRandom.hex(4)}", thousands: ",", colors: chart_colors, stacked: @stacked,
         prefix: @prefix, round: @round, height: @height, legend: false, library: chart_library}.compact
      end

      # false is how Chart.js turns a plugin off
      def chart_library
        {plugins: {htmlLegend: legend? && {prefix: @prefix, round: @round}.compact}}.deep_merge(@library.to_h)
      end

      # Chartkick paints single-series column bars per-color from a flat array;
      # collapse to one so bars are uniform.
      def chart_colors
        (@kind == :column && @series.is_a?(Hash)) ? [@colors.first] : @colors
      end
    end
  end
end
