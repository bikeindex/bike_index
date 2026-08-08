# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module TheftAlertWithoutPhoto
      class Component < ApplicationComponent
        MODAL_ID = "theft-alert-missing-photo"

        def initialize(bikes:)
          @bikes = bikes
        end

        def render?
          @bikes.present?
        end

        private

        def bike_type
          @bikes.first.type
        end
      end
    end
  end
end
