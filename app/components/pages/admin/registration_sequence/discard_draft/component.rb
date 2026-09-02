# frozen_string_literal: true

module Pages
  module Admin
    module RegistrationSequence
      module DiscardDraft
        # Throwing the draft away, at the bottom of every admin sequence screen - away from
        # the header's actions, which all keep it
        class Component < ApplicationComponent
          def initialize(registration_sequence:)
            @registration_sequence = registration_sequence
          end

          def render? = @registration_sequence.draft?

          private

          def discard_path = RegistrationSequencePaths.sequence(@registration_sequence, admin: true)

          def confirm_text = ::RegistrationSequence::DISCARD_DRAFT_CONFIRM
        end
      end
    end
  end
end
