# frozen_string_literal: true

module Pages
  module MyAccount
    module PosRegistrationMatches
      module Show
        class Component < ApplicationComponent
          def initialize(bike:, pos_bike:, pos_registration_match:)
            @bike = bike
            @pos_bike = pos_bike
            @pos_registration_match = pos_registration_match
          end

          private

          def bike_type = @pos_bike.type

          def shop_name = @pos_bike.creation_organization&.short_name
        end
      end
    end
  end
end
