# frozen_string_literal: true

module Pages
  module Register
    module Parts
      module LandingDonation
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Register::Parts::LandingDonation::Component.new)
          end
        end
      end
    end
  end
end
