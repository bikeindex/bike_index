# frozen_string_literal: true

module Registrations
  module Show
    module BikeDetails
      # The "Bike details" spec-sheet card. The serial is rendered for the given
      # user, so the public view passes nil to keep a hidden serial hidden.
      class Component < ApplicationComponent
        include BikeHelper

        def initialize(bike:, serial_user: nil, skip_serial_explanation: false)
          @bike = bike
          @serial_user = serial_user
          @skip_serial_explanation = skip_serial_explanation
        end
      end
    end
  end
end
