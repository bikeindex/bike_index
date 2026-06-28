# frozen_string_literal: true

module Org
  module RegistrationSequence
    # Read-only renderer for a RegistrationSequence's pages, shared by the org show/preview views
    # and the admin review view so the live and upcoming versions render identically.
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
