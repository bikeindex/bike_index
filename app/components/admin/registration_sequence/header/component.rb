# frozen_string_literal: true

module Admin
  module RegistrationSequence
    module Header
      # Shared by every admin registration-sequence screen: which sequence is open,
      # what's being done to it, and the switch between its three screens.
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

        # Activation freezes a sequence, so its Edit is offered but inert
        def entries
          [{label: "View", href: RegistrationSequencePaths.sequence(@registration_sequence, admin: true), active: @mode == :view},
            {label: "Preview", href: RegistrationSequencePaths.preview(@registration_sequence, admin: true), active: @mode == :preview},
            {label: "Edit", href: RegistrationSequencePaths.edit(@registration_sequence, admin: true),
             active: @mode == :edit, disabled: !@registration_sequence.editable?}]
        end

        # Archived sequences are frozen too, so name which one this is
        def uneditable_title
          return if @registration_sequence.editable?

          "Can't edit #{@registration_sequence.status_display.downcase} registration sequence - create a draft"
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
