# frozen_string_literal: true

module Org
  module RegistrationSequence
    # A read-only walk-through of what a registrant sees: each page's rules as
    # checkboxes, then the final acknowledgment binding them to it.
    module Preview
      class Component < ApplicationComponent
        def initialize(registration_sequence:)
          @registration_sequence = registration_sequence
        end

        def render?
          @registration_sequence.present?
        end

        private

        def organization_name
          @registration_sequence.organization&.short_name
        end
      end
    end
  end
end
