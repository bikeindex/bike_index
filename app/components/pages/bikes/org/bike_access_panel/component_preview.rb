# frozen_string_literal: true

module Pages
  module Bikes
    module Org
      module BikeAccessPanel
        class ComponentPreview < ApplicationComponentPreview
          # @display legacy_stylesheet true
          def default
            # TODO: render something - without personal info
            organization = Organization.friendly_find("brakebills")
            bike = nil
            current_user = nil
            render(Pages::Bikes::Org::BikeAccessPanel::Component.new(bike:, organization:, current_user:))
          end
        end
      end
    end
  end
end
