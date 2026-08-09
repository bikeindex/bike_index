# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PageForm
      # Adding or editing one page of a sequence, with the registrant's view of it below.
      class Component < ApplicationComponent
        def initialize(page:, admin: false)
          @page = page
          @registration_sequence = page.registration_sequence
          @admin = admin
        end

        private

        # A new page has nothing to preview or delete yet
        def editing? = @page.persisted?

        def form_url
          editing? ? page_path : RegistrationSequencePaths.pages(@registration_sequence, admin: @admin)
        end

        def page_path = RegistrationSequencePaths.page(@page, admin: @admin)

        def sequence_path = RegistrationSequencePaths.edit(@registration_sequence, admin: @admin)
      end
    end
  end
end
