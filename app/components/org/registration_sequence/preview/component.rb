# frozen_string_literal: true

module Org
  module RegistrationSequence
    # A faked walk-through of the registrant flow: one page of rules per screen, paged
    # through with Continue/Back, ending on the acknowledgment review - so an org sees
    # exactly what registrants see. index == pages.count is that review screen.
    module Preview
      class Component < ApplicationComponent
        def initialize(registration_sequence:, index: 0)
          @registration_sequence = registration_sequence
          @index = index.to_i.clamp(0, pages.count)
        end

        def render?
          @registration_sequence.present?
        end

        private

        def pages
          @pages ||= @registration_sequence.registration_sequence_pages.to_a
        end

        def reviewing?
          @index >= pages.count
        end

        def current_page
          pages[@index]
        end

        # The rule pages plus the review they end on
        def total_steps
          pages.count + 1
        end

        def continue_path
          preview_path(@index + 1)
        end

        def back_path
          @index.zero? ? exit_path : preview_path(@index - 1)
        end

        def preview_path(index)
          organization_registration_sequence_path(organization_id: organization.to_param,
            id: @registration_sequence.id, page: index)
        end

        # The show path itself - a GET form appends ?page= from a hidden field, since a
        # form's own query string is dropped on submit
        def sequence_path
          organization_registration_sequence_path(organization_id: organization.to_param, id: @registration_sequence.id)
        end

        # Leaving the preview: back to the draft's editor, or the index for a live one
        def exit_path
          if @registration_sequence.draft?
            edit_organization_registration_sequence_path(organization_id: organization.to_param, id: @registration_sequence.id)
          else
            organization_registration_sequences_path(organization_id: organization.to_param)
          end
        end

        def organization
          @registration_sequence.organization
        end
      end
    end
  end
end
