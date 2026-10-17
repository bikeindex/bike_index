# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module SafetyCard
        # What to do on spotting the stolen bike, beside the wizard and the next steps
        class Component < ApplicationComponent
          def initialize(bike_type:)
            @bike_type = bike_type
          end
        end
      end
    end
  end
end
