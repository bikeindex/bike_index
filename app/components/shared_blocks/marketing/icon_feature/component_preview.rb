# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module IconFeature
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(SharedBlocks::Marketing::IconFeature::Component.new(icon: "icons/searcher.svg", circle: "tw:bg-blue-600",
            title: "Free registration", body: "Registering, searching and checking a bike cost nothing."))
        end

        def card
          render(SharedBlocks::Marketing::IconFeature::Component.new(icon: "icons/megaphone.svg", circle: "tw:bg-purple-500",
            title: "Stolen bike alerts", body: "Theft reports go out to shops, police and riders nearby.", card: true))
        end
      end
    end
  end
end
