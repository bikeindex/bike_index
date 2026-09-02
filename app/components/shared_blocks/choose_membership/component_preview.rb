# frozen_string_literal: true

module SharedBlocks
  module ChooseMembership
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(SharedBlocks::ChooseMembership::Component.new(currency: Currency.default))
      end
    end
  end
end
