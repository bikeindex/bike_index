# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module BikeDetails
        # The "Bike details" spec-sheet card. The serial is rendered for the given
        # user, so the public view passes nil to keep a hidden serial hidden.
        class Component < ApplicationComponent
          def initialize(bike:, serial_user: nil, skip_serial_explanation: false)
            @bike = bike
            @serial_user = serial_user
            @skip_serial_explanation = skip_serial_explanation
          end

          private

          def manufacturer_name
            @bike.manufacturer&.other? ? @bike.mnfg_name : @bike.manufacturer&.name
          end

          # Only vehicles that aren't a standard bike surface the type
          def vehicle_type
            @bike.cycle_type_name unless @bike.type == "bike"
          end
        end
      end
    end
  end
end
