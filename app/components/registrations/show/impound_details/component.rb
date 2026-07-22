# frozen_string_literal: true

module Registrations
  module Show
    module ImpoundDetails
      # Impound location and date for an impounded bike — mirrors the stolen card
      class Component < ApplicationComponent
        def initialize(bike:)
          @bike = bike
        end

        def render?
          @bike.status_impounded? && impound_record.present?
        end

        private

        def found?
          @bike.status_found?
        end

        def impound_record
          @impound_record ||= @bike.current_impound_record
        end
      end
    end
  end
end
