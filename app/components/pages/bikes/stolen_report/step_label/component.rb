# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module StepLabel
        # A step's name, the same in the wizard and the registration that hands off to it
        class Component < ApplicationComponent
          # bike_type: titleized, it starts the registration steps' names
          def initialize(step:, bike_type:)
            @step = step
            @bike_type = bike_type
          end

          def call = h(label)

          private

          def label
            case @step
            when "bike_info" then translation(".bike_info", bike_type: @bike_type)
            when "bike_details" then translation(".bike_details", bike_type: @bike_type)
            when "where" then translation(".where")
            when "lock" then translation(".lock")
            when "photos" then translation(".photos")
            when "police" then translation(".police")
            when "contact" then translation(".contact")
            when "extra" then translation(".extra")
            else translation(".review")
            end
          end
        end
      end
    end
  end
end
