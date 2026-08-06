# frozen_string_literal: true

module Register
  module PageContent
    # One registration-sequence page rendered the way a registrant sees it: badge, heading,
    # image, the page title as a section label with the FAQ link, and its rules as a checkbox
    # list. Shared by the live acknowledgment flow and the org's preview so the two can't
    # drift. All the caller supplies is how a rule's checkbox renders - a real form input in
    # the flow, a decorative one in the preview.
    class Component < ApplicationComponent
      # first: the flow's opening page, where the registrant is told why these appeared
      # control: ->(index) { the checkbox tag for bullet `index` }
      def initialize(page:, control:, first: false)
        @page = page
        @control = control
        @first = first
      end

      private

      def sequence
        @page.registration_sequence
      end

      def organization_name
        sequence.organization&.short_name
      end
    end
  end
end
