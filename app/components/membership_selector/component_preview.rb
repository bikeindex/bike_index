# frozen_string_literal: true

module MembershipSelector
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(MembershipSelector::Component.new())
    end
  end
end
