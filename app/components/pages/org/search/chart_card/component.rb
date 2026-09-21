# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ChartCard
        # The chart and headline counts beside an org search - the registrations one with
        # both scopes and the stats, the others on their own search alone.
        #
        # The caption lives inside the turbo-frame, so a scope switch or a new search brings
        # it back in step with the numbers in one response.
        # `src` renders the placeholder, `chart`/`stats` the response.
        #
        # The collapse trigger stays outside the frame: a frame render replaces what's in it,
        # and while the card is collapsed the lazy frame has nothing to load yet.
        class Component < ApplicationComponent
          FRAME_ID = :chart_card_frame
          CHART_HEIGHT = "180px"
          # Holds the space a loaded card takes, so the page doesn't shift when it lands
          PLACEHOLDER_CLASSES = "tw:flex tw:min-h-[300px] tw:items-center tw:justify-center"

          # The open state is part of the address rather than a stored preference; the scope
          # links carry it, since org--chart-card-scope-links rebuilds them from the URL
          COLLAPSE_PARAM = "chart_open"

          # Display order, per Kelsey's redesign
          SCOPES = %w[year search].freeze
          DEFAULT_SCOPE = "year"

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

          def caption = translation(".caption_#{@scope}")

          def follows_search? = @scope == "search"

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

          def delta_tooltip(stat)
            # The body rather than text:, which would replace the badge as the button's name
            UI::Tooltip::Component.new.with_body_content(translation(".previous_#{@scope}",
              previous_count: number_with_delimiter(stat.previous_count)))
          end
        end
      end
    end
  end
end
