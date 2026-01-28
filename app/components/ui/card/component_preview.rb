# frozen_string_literal: true

module UI::Card
  class ComponentPreview < ApplicationComponentPreview
    # @group Kind Variants
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
  end
end
