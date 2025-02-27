# frozen_string_literal: true

module ChooseMembership
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(ChooseMembership::Component.new(currency: Currency.default))
    end
  end
end
