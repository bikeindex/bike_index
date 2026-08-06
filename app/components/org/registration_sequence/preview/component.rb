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
          @index = index
        end

        def render?
          @registration_sequence.present?
        end

        private

        def pages
          BikeServices::Register.sequence_pages(@registration_sequence)
        end

        def reviewing?
          @index >= pages.count
        end

        def current_page
          pages[@index]
        end

        # The registration's step math, so the progress bars match the real flow. The
        # review is one past the pages, which is exactly the review's step there too.
        def progress_step
          BikeServices::Register.step_for_page_index(@index).to_i
        end

        def progress_total
          BikeServices::Register.total_steps(@registration_sequence)
        end

        def acknowledgment_step_count
          BikeServices::Register.acknowledgment_step_count(@registration_sequence)
        end

        def back_path
          @index.zero? ? exit_path : sequence_path(page: @index)
        end

        # The URL page param is 1-indexed; @index is 0-based
        def page_param(index) = index + 1

        # A GET form appends ?page= from a hidden field, since a form's own query string
        # is dropped on submit
        def sequence_path(page: nil)
          organization_registration_sequence_path(organization_id: organization.to_param,
            id: @registration_sequence.id, page:)
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
