# frozen_string_literal: true

module PageBlock
  module ChooseMembership
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(PageBlock::ChooseMembership::Component.new(currency: Currency.default))
      end
    end
  end
end
