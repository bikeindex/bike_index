# frozen_string_literal: true

module PageSection::ChooseMembership
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(PageSection::ChooseMembership::Component.new(currency: Currency.default))
    end
  end
end
