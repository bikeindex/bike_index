# frozen_string_literal: true

module Pages
  module Org
    module Search
      module AtAGlance
        # The chart and headline counts beside the org registrations search.
        #
        # Everything lives inside the turbo-frame, header included, so a scope switch or a
        # new search brings the caption and the numbers back in step in one response. The
        # card renders with `src` on the page itself and with `chart`/`stats` in the frame's
        # own response — the same two modes as UI::ChartAsyncFrame, which it wraps.
        class Component < ApplicationComponent
          FRAME_ID = :registrations_chart_frame

          SCOPES = {search: "search", year: "year"}.freeze

          def self.permitted_scope(scope)
            SCOPES.fetch(scope.to_s.to_sym, SCOPES[:search])
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
            SCOPES.keys.map do |key|
              ComponentStructs::Shapes.entry(translation(".scope_#{key}"), href: @scope_paths[key],
                active: @scope == SCOPES[key], data: {turbo_frame: FRAME_ID})
            end
          end

          def stat_color(key)
            {registrations: "tw:bg-blue-600", motorized: "tw:bg-purple-500", stolen: "tw:bg-red-600"}[key]
          end

          def delta_classes(stat)
            base = "tw:rounded-full tw:px-2 tw:py-0.5 tw:text-2xs tw:font-bold"
            tone = stat.positive? ? "tw:bg-green-50 tw:text-green-700" : "tw:bg-red-50 tw:text-red-700"
            "#{base} #{tone}"
          end
        end
      end
    end
  end
end
