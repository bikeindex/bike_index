# frozen_string_literal: true

module Pages
  module Register
    module Parts
      module PageContent
        # One registration-sequence page as a registrant sees it. Shared by the live
        # acknowledgment flow and the org's preview of it, so the two can't drift.
        class Component < ApplicationComponent
          # first: the flow's opening page, where the registrant is told why these appeared
          # checkbox_name: the rules submit as checkbox_name[index]; nil leaves them decorative
          # heading_tag: below h1 where the page is embedded in another
          def initialize(page:, first: false, checkbox_name: nil, checked: false, heading_tag: :h1)
            @page = page
            @first = first
            @checkbox_name = checkbox_name
            @checked = checked
            @heading_tag = heading_tag
          end

          private

          def sequence
            @page.registration_sequence
          end

          # What the editor promised - "Template" when admin previews the template
          def badge_name
            sequence&.badge_name
          end

          # The template's rules are Bike Index's
          def set_by_name
            sequence&.organization&.name || translation(".bike_index")
          end

          def checkbox_name(index)
            "#{@checkbox_name}[#{index}]" if @checkbox_name.present?
          end
        end
      end
    end
  end
end
