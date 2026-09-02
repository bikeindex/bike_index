# frozen_string_literal: true

module Pages
  module Org
    module RegistrationSequence
      # A faked walk-through of the registrant flow: one page of rules per screen, paged
      # through with Continue/Back, ending on the acknowledgment review - so an org sees
      # exactly what registrants see. index == pages.count is that review screen.
      module Preview
        class Component < ApplicationComponent
          def initialize(registration_sequence:, index: 0, admin: false)
            @registration_sequence = registration_sequence
            @index = index
            @admin = admin
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

          # The registration's own steps, so the progress bar matches the real flow. No
          # b_param, so it's the flow without a report - which is what a preview walks
          def progress_steps
            @progress_steps ||= BikeServices::Register.steps(nil, sequence: @registration_sequence)
          end

          def progress_step
            reviewing? ? "review" : BikeServices::Register.step_for_page_index(@index)
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
            RegistrationSequencePaths.preview(@registration_sequence, page:, admin: @admin)
          end

          def exit_path
            RegistrationSequencePaths.preview_exit(@registration_sequence, admin: @admin)
          end
        end
      end
    end
  end
end
