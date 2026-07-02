# frozen_string_literal: true

module Org
  module RegistrationSequence
    # Read-only renderer for a RegistrationSequence's pages, used by the org show (preview) view.
    module Preview
      class Component < ApplicationComponent
        def initialize(registration_sequence:)
          @registration_sequence = registration_sequence
        end

        def render?
          @registration_sequence.present?
        end
      end
    end
  end
end
