# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module NumberBlocks
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(SharedBlocks::Marketing::NumberBlocks::Component.new(items: [["1.7M+", "bikes registered"],
            ["17,387", "stolen bikes recovered"], ["$33M+", "value returned to owners"],
            ["1,800+", "partner shops, police departments, and cities"]]))
        end
      end
    end
  end
end
