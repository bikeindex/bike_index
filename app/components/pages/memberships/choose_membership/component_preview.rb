# frozen_string_literal: true

module Pages
  module Memberships
    module ChooseMembership
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Memberships::ChooseMembership::Component.new(currency: Currency.default))
        end
      end
    end
  end
end
