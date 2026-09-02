# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module PrimaryColors
        # The primary color(s) definition-list row: a swatch + name per frame color,
        # joined by "and". Renders nothing when the bike has no colors.
        class Component < ApplicationComponent
          def initialize(bike:)
            @bike = bike
          end

          def render?
            frame_color_records.any?
          end

          def call
            render(UI::DefinitionList::Row::Component.new(label:)) do
              safe_join(color_swatches, content_tag(:span, " and ", class: "tw:font-normal tw:text-gray-400"))
            end
          end

          private

          def frame_color_records
            [@bike.primary_frame_color, @bike.secondary_frame_color, @bike.tertiary_frame_color].compact
          end

          def label
            translation(".primary_color", count: frame_color_records.count)
          end

          # A non-breaking space keeps the swatch with the first word; the rest of a
          # long color name wraps, and the " and " between colors still breaks.
          def color_swatches
            frame_color_records.map do |color|
              swatch = render(UI::ColorSwatch::Component.new(display: color.display, name: color.name, size: :sm, align: :baseline))
              safe_join([swatch, "\u00a0", color.name])
            end
          end
        end
      end
    end
  end
end
