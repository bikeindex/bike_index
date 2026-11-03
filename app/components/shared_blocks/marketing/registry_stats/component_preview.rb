# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module RegistryStats
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(SharedBlocks::Marketing::RegistryStats::Component.new)
        end
      end
    end
  end
end
