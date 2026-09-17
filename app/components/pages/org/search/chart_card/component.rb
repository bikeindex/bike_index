# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ChartCard
        # The chart and headline counts beside the org registrations search.
        #
        # Everything lives inside the turbo-frame, header included, so a scope switch or a
        # new search brings the caption and the numbers back in step in one response — which
        # is why this renders its own frame rather than UI::ChartAsyncFrame's, whose wrapper
        # holds only the chart. `src` renders the placeholder, `chart`/`stats` the response.
        class Component < ApplicationComponent
          FRAME_ID = :registrations_chart_frame

          # Display order, per Kelsey's redesign; the search is what the page opens on
          SCOPES = %w[year search].freeze
          DEFAULT_SCOPE = "search"

          # The controller builds the series from the hex, so a color change moves the bar
          # and its stat row's swatch together
          BANDS = {registrations: {hex: "#2563eb", swatch: "tw:bg-blue-600"},
                   motorized: {hex: "#a855f7", swatch: "tw:bg-purple-500"},
                   stolen: {hex: "#dc2626", swatch: "tw:bg-red-600"}}.freeze

          def self.permitted_scope(scope)
            SCOPES.include?(scope.to_s) ? scope.to_s : DEFAULT_SCOPE
          end

          def initialize(src: nil, scope: nil, scope_paths: {}, chart: nil, stats: [])
            @src = src
            @scope = self.class.permitted_scope(scope)
            @scope_paths = scope_paths
            @chart = chart
            @stats = stats
          end

          private

          def caption
            translation((@scope == "year") ? ".caption_year" : ".caption_search")
          end

          def scope_entries
            SCOPES.map do |scope|
              ComponentStructs::Shapes.entry(translation(".scope_#{scope}"), href: @scope_paths[scope.to_sym],
                active: @scope == scope, data: {turbo_frame: FRAME_ID, turbo_action: "advance"})
            end
          end

          def delta_badge(stat)
            UI::Badge::Component.new(text: stat.delta_display, size: :xs,
              color: stat.positive? ? :success : :error)
          end
        end
      end
    end
  end
end
