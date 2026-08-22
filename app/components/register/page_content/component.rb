# frozen_string_literal: true

module Register
  module PageContent
    # One registration-sequence page as a registrant sees it. Shared by the live
    # acknowledgment flow and the org's preview of it, so the two can't drift.
    class Component < ApplicationComponent
      # first: the flow's opening page, where the registrant is told why these appeared
      # checkbox_name: the rules submit as checkbox_name[index]; nil leaves them decorative
      def initialize(page:, first: false, checkbox_name: nil, checked: false)
        @page = page
        @first = first
        @checkbox_name = checkbox_name
        @checked = checked
      end

      private

      def sequence
        @page.registration_sequence
      end

      # Only the e-vehicle sequence is chosen by what's being registered, so it's the
      # only one that opens by announcing it
      def electric_detected? = @first && sequence&.e_vehicle?

      # What the editor promised - "Template" when admin previews the template
      def badge_name
        sequence&.badge_name
      end

      def checkbox_name(index)
        "#{@checkbox_name}[#{index}]" if @checkbox_name.present?
      end
    end
  end
end
