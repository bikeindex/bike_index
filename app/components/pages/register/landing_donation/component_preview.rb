# frozen_string_literal: true

module Pages
  module Register
    module LandingDonation
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Register::LandingDonation::Component.new)
        end
      end
    end
  end
end
