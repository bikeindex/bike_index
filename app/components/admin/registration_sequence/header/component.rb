# frozen_string_literal: true

module Admin
  module RegistrationSequence
    module Header
      # The header every admin registration-sequence screen shares: which sequence
      # is open and what's being done to it, the switch between its three screens,
      # and a link to the organization's own.
      class Component < ApplicationComponent
        MODES = %i[view preview edit].freeze
        ACTION_WORDS = {view: "Viewing", preview: "Previewing", edit: "Editing"}.freeze

        def initialize(registration_sequence:, mode: :view)
          raise ArgumentError, "mode must be one of #{MODES.inspect}, got #{mode.inspect}" unless MODES.include?(mode)

          @registration_sequence = registration_sequence
          @mode = mode
        end

        private

        def action_word = ACTION_WORDS[@mode]

        # Activation freezes a sequence, so editing a live one is offered but inert
        def entries
          [{label: "View", href: RegistrationSequencePaths.sequence(@registration_sequence, admin: true), active: @mode == :view},
            {label: "Preview", href: RegistrationSequencePaths.preview(@registration_sequence, admin: true), active: @mode == :preview},
            {label: "Edit", href: RegistrationSequencePaths.edit(@registration_sequence, admin: true),
             active: @mode == :edit, disabled: !@registration_sequence.draft?}]
        end

        # Archived sequences are frozen too, so the status says which one this is
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

        # This sequence on the organization's own screens; the template has no organization
        def organization_sequence_path
          return if @registration_sequence.template?

          RegistrationSequencePaths.sequence(@registration_sequence)
        end
      end
    end
  end
end
