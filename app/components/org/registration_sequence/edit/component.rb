# frozen_string_literal: true

module Org
  module RegistrationSequence
    module Edit
      # Draft management UI: the drag-to-reorder page list with per-page Edit
      # links and the sequence-wide settings form.
      class Component < ApplicationComponent
        def initialize(registration_sequence:)
          @registration_sequence = registration_sequence
          @organization = registration_sequence.organization
        end

        private

        def pages
          @pages ||= @registration_sequence.registration_sequence_pages.to_a
        end
      end
    end
  end
end
