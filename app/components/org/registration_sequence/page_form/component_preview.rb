# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PageForm
      class ComponentPreview < ApplicationComponentPreview
        # A saved page, so the form has the preview below it that editing marks stale
        def default
          page = editable_pages.last
          return missing_notice("registration sequence pages") if page.blank?

          render(Org::RegistrationSequence::PageForm::Component.new(page:))
        end

        # Adding one - no preview to go stale, and it POSTs rather than PATCHes
        def new_page
          sequence = organization_drafts.last
          return missing_notice("draft registration sequences") if sequence.blank?

          render(Org::RegistrationSequence::PageForm::Component.new(page: sequence.registration_sequence_pages.new))
        end

        private

        # An activated sequence's pages have no editor, so they'd render paths that 404.
        # The template's pages are edited in admin, so they'd render the wrong ones
        def organization_drafts = ::RegistrationSequence.draft.where.not(organization_id: nil)

        def editable_pages
          ::RegistrationSequencePage.where(registration_sequence: organization_drafts)
        end
      end
    end
  end
end
