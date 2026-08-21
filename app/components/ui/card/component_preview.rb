# frozen_string_literal: true

module UI
  module Card
    class ComponentPreview < ApplicationComponentPreview
      # @!group Kind Variants
      def default
        render(UI::Card::Component.new) do
          "Man braid sustainable solarpunk vexillologist grailed marxism schlitz big mood shabby chic cornhole yuccie PBR&B vegan."
        end
      end

      def with_shadow
        render(UI::Card::Component.new(shadow: true)) do
          "Man braid sustainable solarpunk vexillologist grailed marxism schlitz big mood shabby chic cornhole yuccie PBR&B vegan."
        end
      end

      # The template supplies the .twwiderow full_bleed is keyed to. Narrow the preview until
      # the row drops to one column to see the cards lose their sides and meet the gutter
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
