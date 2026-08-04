# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PagePreview
      # A single sequence page shown as a registrant sees it (via Register::PageContent),
      # with decorative checkboxes. Used stacked in the full preview and beneath the page
      # editor.
      class Component < ApplicationComponent
        def initialize(page:)
          @page = page
          @sequence = page.registration_sequence
        end

        private

        def organization_name
          @sequence.organization&.short_name
        end
      end
    end
  end
end
