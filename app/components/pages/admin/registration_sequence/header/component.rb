# frozen_string_literal: true

module Pages
  module Admin
    module RegistrationSequence
      module Header
        # Shared by every admin registration-sequence screen: which sequence is open,
        # what's being done to it, and the switch between its three screens.
        class Component < ApplicationComponent
          ACTION_WORDS = {view: "Viewing", preview: "Previewing", edit: "Editing"}.freeze
          MODES = ACTION_WORDS.keys.freeze

          def initialize(registration_sequence:, mode: :view)
            raise ArgumentError, "mode must be one of #{MODES.inspect}, got #{mode.inspect}" unless MODES.include?(mode)

            @registration_sequence = registration_sequence
            @mode = mode
          end

          private

          def action_word = ACTION_WORDS[@mode]

          # Activation freezes a sequence, so its Edit is offered but inert
          def entries
            [ComponentStructs::Shapes.entry("View",
              href: RegistrationSequencePaths.sequence(@registration_sequence, admin: true), active: @mode == :view),
              ComponentStructs::Shapes.entry("Preview",
                href: RegistrationSequencePaths.preview(@registration_sequence, admin: true), active: @mode == :preview),
              ComponentStructs::Shapes.entry("Edit",
                href: RegistrationSequencePaths.edit(@registration_sequence, admin: true),
                active: @mode == :edit, disabled: !@registration_sequence.draft?)]
          end

          # Archived sequences are frozen too, so name which one this is
          def uneditable_title
            return if @registration_sequence.draft?

            "Can't edit #{@registration_sequence.status_display.downcase} registration sequence - create a draft"
          end

          def activate_path = RegistrationSequencePaths.activate(@registration_sequence)

          def create_draft_path = RegistrationSequencePaths.create_draft(@registration_sequence.organization_id)

          # What the frozen sequence offers in place of its inert Edit chip. The draft belongs
          # to the owner rather than to this sequence, so a second archived one points at it too
          def create_draft_text
            return "Edit draft" if ::RegistrationSequence.existing_draft_for(@registration_sequence.organization).present?

            "Create draft"
          end

          def activate_confirm
            "Make this the live #{@registration_sequence.badge_name} registration sequence? " \
              "It can't be edited afterward."
          end

          # The template has no organization to view it in
          def organization_sequence_path
            return if @registration_sequence.template?

            RegistrationSequencePaths.sequence(@registration_sequence)
          end
        end
      end
    end
  end
end
