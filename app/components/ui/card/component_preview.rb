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

      # Narrow the preview to see the sides go, so the content meets the page's gutter
      def mobile_flush
        render(UI::Card::Component.new(mobile_flush: true)) do
          "Man braid sustainable solarpunk vexillologist grailed marxism schlitz big mood shabby chic cornhole yuccie PBR&B vegan."
        end
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
