# frozen_string_literal: true

module Org
  module RegistrationSequence
    module Edit
      # Draft management UI: page-count header with Add page, and the
      # drag-to-reorder list of pages with per-page Edit links.
      class Component < ApplicationComponent
        def initialize(registration_sequence:)
          @registration_sequence = registration_sequence
          @organization = registration_sequence.organization
        end

        private

        def pages
          @pages ||= @registration_sequence.registration_sequence_pages.to_a
        end
      end
    end
  end
end
