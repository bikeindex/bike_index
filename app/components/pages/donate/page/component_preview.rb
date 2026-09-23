# frozen_string_literal: true

module Pages
  module Donate
    module Page
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Donate::Page::Component.new(recovery_displays: RecoveryDisplay.limit(8)))
        end

        # From a major gift link, or a newsletter's "donate $500"
        def initial_amount
          render(Pages::Donate::Page::Component.new(recovery_displays: [], initial_amount: "500"))
        end
      end
    end
  end
end
