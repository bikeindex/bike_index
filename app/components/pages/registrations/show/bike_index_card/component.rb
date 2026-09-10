# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module BikeIndexCard
        # The "This bike on Bike Index" summary card. The caller passes the
        # definition-list term to control the layout.
        class Component < ApplicationComponent
          def initialize(bike:, term:)
            @bike = bike
            @term = term
          end

          private

          def activity_name
            @bike.primary_activity&.display_name
          end
        end
      end
    end
  end
end
