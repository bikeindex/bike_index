# frozen_string_literal: true

module Pages
  module Register
    module StartPage
      # The page the flow opens on - its progress, heading and errors - around whichever
      # form asks for step 1: its own, or the one that asks for both steps
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, organization:, subtitle: nil, embed: false, skip_heading: false)
          @b_param = b_param
          @steps = steps
          @organization = organization
          @subtitle = subtitle
          @embed = embed
          @skip_heading = skip_heading
        end

        private

        # The step is still asking what's being registered, so the heading can't name the
        # type. Framed, the page around it already says whose registration this is
        def heading_text
          return translation(".register_your_vehicle") if @embed || @organization.blank?

          translation(".register_your_vehicle_with_org", org_name: @organization.short_name)
        end
      end
    end
  end
end
