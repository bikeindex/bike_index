# frozen_string_literal: true

module Card
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Card::Component.new) do
        "Man braid sustainable solarpunk vexillologist grailed marxism schlitz big mood shabby chic cornhole yuccie PBR&B vegan."
      end
    end
  end
end
