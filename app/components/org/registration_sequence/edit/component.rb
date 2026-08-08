# frozen_string_literal: true

module Org
  module RegistrationSequence
    module Edit
      # Sequence management UI: the drag-to-reorder page list with per-page Edit
      # links and the sequence-wide settings form. Admin opens this on any sequence,
      # so an activated one - which acknowledgments freeze - renders read-only.
      class Component < ApplicationComponent
        def initialize(registration_sequence:, admin: false)
          @registration_sequence = registration_sequence
          @admin = admin
          @paths = RegistrationSequencePaths.new(admin:)
        end

        private

        def pages
          @pages ||= @registration_sequence.registration_sequence_pages.to_a
        end
      end
    end
  end
end
