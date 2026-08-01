# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module TheftAlertWithoutPhoto
      # Opens on page load, linking each promoted alert missing an image to the bike's
      # photos form
      class Component < ApplicationComponent
        MODAL_ID = "theft-alert-missing-photo"

        def initialize(bikes:)
          @bikes = bikes
        end

        def render?
          @bikes.present?
        end
      end
    end
  end
end
