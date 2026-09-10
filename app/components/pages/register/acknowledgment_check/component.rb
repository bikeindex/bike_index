# frozen_string_literal: true

module Pages
  module Register
    module AcknowledgmentCheck
      # The final "I, <name>, <acknowledgment>" the review is signed with.
      class Component < ApplicationComponent
        # registrant_name: nil in the org's preview, where nobody is signing - a placeholder
        # stands in for whoever will
        def initialize(sequence:, registrant_name: nil, checkbox_name: nil)
          @sequence = sequence
          @registrant_name = registrant_name
          @checkbox_name = checkbox_name
        end

        private

        def name_html
          return content_tag(:strong, @registrant_name) if @registrant_name.present?

          content_tag(:em, translation(".registrants_name"))
        end
      end
    end
  end
end
