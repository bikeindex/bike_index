# frozen_string_literal: true

module Admin
  module RegistrationSequence
    module Header
      # The header every admin registration-sequence screen shares: which sequence
      # is open and what's being done to it, with links to the other view of it and
      # to the organization's own.
      class Component < ApplicationComponent
        # previewing: the registrant walk-through, rather than the editor
        def initialize(registration_sequence:, previewing: false)
          @registration_sequence = registration_sequence
          @previewing = previewing
        end

        private

        # Activation freezes a sequence, so its editor only ever shows it
        def action_word
          return "Previewing" if @previewing

          @registration_sequence.editable? ? "Editing" : "Viewing"
        end

        def switch_text
          return "Preview" unless @previewing

          @registration_sequence.editable? ? "Edit" : "View"
        end

        def switch_path
          if @previewing
            RegistrationSequencePaths.edit(@registration_sequence, admin: true)
          else
            RegistrationSequencePaths.sequence(@registration_sequence, admin: true)
          end
        end

        # The organization's own copy of this screen; the template has no organization
        def organization_path
          return if @registration_sequence.template?

          RegistrationSequencePaths.sequence(@registration_sequence)
        end
      end
    end
  end
end
