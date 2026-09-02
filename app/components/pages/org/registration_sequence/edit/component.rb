# frozen_string_literal: true

module Pages
  module Org
    module RegistrationSequence
      module Edit
        # The drag-to-reorder page list and the sequence-wide settings form.
        class Component < ApplicationComponent
          def initialize(registration_sequence:, admin: false)
            @registration_sequence = registration_sequence
            @admin = admin
            @editable = registration_sequence.draft?
          end

          private

          def pages
            @pages ||= @registration_sequence.registration_sequence_pages.to_a
          end

          def new_page_path = RegistrationSequencePaths.new_page(@registration_sequence, admin: @admin)

          def sequence_path = RegistrationSequencePaths.sequence(@registration_sequence, admin: @admin)
        end
      end
    end
  end
end
