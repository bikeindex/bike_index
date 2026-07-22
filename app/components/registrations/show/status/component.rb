# frozen_string_literal: true

module Registrations
  module Show
    module Status
      # The stolen/found/impounded/registered status badge.
      class Component < ApplicationComponent
        def initialize(bike:)
          @bike = bike
        end

        def call
          render(UI::Badge::Component.new(text: label, color: color, indicator: true))
        end

        private

        def label
          if @bike.status_stolen?
            translation(".stolen")
          elsif @bike.status_found?
            translation(".found")
          elsif @bike.status_impounded?
            translation(".impounded")
          else
            translation(".not_stolen")
          end
        end

        def color
          return :error if @bike.status_stolen?
          return :warning if @bike.status_impounded?

          :success
        end
      end
    end
  end
end
