# frozen_string_literal: true

module Pages
  module LandingPages
    module Lightspeed
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::Lightspeed::Component.new)
        end

        def with_shop
          render(Pages::LandingPages::Lightspeed::Component.new(has_shop: true))
        end
      end
    end
  end
end
