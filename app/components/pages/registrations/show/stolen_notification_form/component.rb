# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module StolenNotificationForm
        class Component < ApplicationComponent
          def initialize(bike:, placeholder: nil)
            @bike = bike
            @placeholder = placeholder
          end

          private

          def placeholder
            @placeholder || translation(".where_did_you_see_this_bike", bike_type: @bike.type)
          end
        end
      end
    end
  end
end
