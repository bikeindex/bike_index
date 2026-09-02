# frozen_string_literal: true

module Pages
  module Org
    module RegistrationSequence
      module PageForm
        class ComponentPreview < ApplicationComponentPreview
          # A saved page has the preview below it that editing marks stale
          def default
            page = editable_pages.last
            return missing_notice("registration sequence pages") if page.blank?

            render(Pages::Org::RegistrationSequence::PageForm::Component.new(page:))
          end

          # Adding one POSTs, and has no preview to go stale
          def new_page
            sequence = organization_drafts.last
            return missing_notice("draft registration sequences") if sequence.blank?

            render(Pages::Org::RegistrationSequence::PageForm::Component.new(page: sequence.registration_sequence_pages.new))
          end

          private

          # An activated sequence's pages have no editor, so their paths 404. The template's
          # are edited in admin, so they'd render the organization's paths for it
          def organization_drafts = ::RegistrationSequence.draft.where.not(organization_id: nil)

          def editable_pages
            ::RegistrationSequencePage.where(registration_sequence: organization_drafts)
          end
        end
      end
    end
  end
end
