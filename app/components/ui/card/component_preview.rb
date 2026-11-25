# frozen_string_literal: true

module UI
  module Card
    class ComponentPreview < ApplicationComponentPreview
      BODY = "Man braid sustainable solarpunk vexillologist grailed marxism schlitz big mood shabby chic cornhole yuccie PBR&B vegan."

      # @!group Kind Variants
      def default
        render(UI::Card::Component.new) do
          BODY
        end
      end

      def with_small_shadow
        render(UI::Card::Component.new(shadow: :small)) do
          BODY
        end
      end

      def with_large_shadow
        render(UI::Card::Component.new(shadow: :large)) do
          BODY
        end
      end

      def with_black_shadow
        render(UI::Card::Component.new(shadow: :black)) do
          BODY
        end
      end

      # The template supplies the .twwiderow full_bleed is keyed to. Narrow the preview until
      # the rows drop to one column to see the cards lose their sides and meet the gutter -
      # the three-column row goes 2+1 first
      def full_bleed
        {template: "ui/card/component_preview/full_bleed"}
      end

      def divided
        render(UI::Card::Component.new(divided: true)) do
          safe_join(["Man braid sustainable solarpunk", "Vexillologist grailed marxism schlitz", "Big mood shabby chic cornhole"]
            .map { |row| tag.div(row, class: "tw:px-4 tw:py-3.5 tw:text-sm") })
        end
      end
    end
  end
end
