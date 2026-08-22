# frozen_string_literal: true

module Org
  module RegistrationSequence
    module KindSection
      # One kind's section of the organization's index, managed independently of the other's
      class Component < ApplicationComponent
        def initialize(organization:, kind:, editable: false)
          @organization = organization
          @kind = kind
          @editable = editable
        end

        private

        def kind_display = ::RegistrationSequence.kind_display(@kind)

        # The live sequence and the draft above it (end_at is what archiving sets) - both
        # list their pages, so those load alongside
        def current
          @current ||= @organization.registration_sequences.where(kind: @kind, end_at: nil)
            .includes(:registration_sequence_pages).to_a
        end

        def active = current.detect(&:active?)

        def draft = current.detect(&:draft?)

        def previous
          @previous ||= @organization.registration_sequences.archived.where(kind: @kind)
            .order(end_at: :desc).to_a
        end

        def sequence_path(registration_sequence)
          RegistrationSequencePaths.sequence(registration_sequence)
        end

        def create_draft_path = RegistrationSequencePaths.create_draft(@organization, kind: @kind)

        def create_draft_text = active.present? ? "Copy current sequence and edit" : "Create a sequence"

        def discard_confirm = "return confirm('#{j ::RegistrationSequence::DISCARD_DRAFT_CONFIRM}')"
      end
    end
  end
end
