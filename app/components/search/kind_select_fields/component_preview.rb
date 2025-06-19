# frozen_string_literal: true

module Search::KindSelectFields
  class ComponentPreview < ApplicationComponentPreview
    # @group Kind scopes
    def default
      render(Search::KindSelectFields::Component.new(kind_scope: "stolen"))
    end

    def chicago_tall_bike
      render(Search::KindSelectFields::Component.new(kind_scope: "proximity",
        location: "Chicago, IL"))
    end

    def for_sale
      render(Search::KindSelectFields::Component.new(kind_scope: "for_sale",
        location: "Chicago, IL"))
    end
    # @endgroup
  end
end
