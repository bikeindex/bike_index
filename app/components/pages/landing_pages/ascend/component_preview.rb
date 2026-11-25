# frozen_string_literal: true

module Pages
  module LandingPages
    module Ascend
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::Ascend::Component.new)
        end

        def with_shop
          render(Pages::LandingPages::Ascend::Component.new(has_shop: true))
        end
      end
    end
  end
end
