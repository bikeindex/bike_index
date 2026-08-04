# frozen_string_literal: true

module Register
  module PageContent
    # One registration-sequence page rendered the way a registrant sees it: heading,
    # image, the page title as a section label, and its rules as a checkbox list. Shared
    # by the live acknowledgment flow and the org's preview so the two can't drift. Each
    # caller supplies the leading badge, the FAQ affordance, and how a rule's checkbox
    # renders - a real form input in the flow, a decorative one in the preview.
    class Component < ApplicationComponent
      renders_one :badge
      renders_one :faq

      # control: ->(index) { the checkbox tag for bullet `index` }
      def initialize(page:, control:)
        @page = page
        @control = control
      end
    end
  end
end
