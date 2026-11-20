# frozen_string_literal: true

module Pages
  module LandingPages
    module Lightspeed
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::Lightspeed::Component.new)
        end

        def signed_in_without_shop
          render(Pages::LandingPages::Lightspeed::Component.new(signed_in: true))
        end

        def with_shop
          render(Pages::LandingPages::Lightspeed::Component.new(has_shop: true))
        end
      end
    end
  end
end
