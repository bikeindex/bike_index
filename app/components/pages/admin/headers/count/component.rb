# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Count
        # Goes after an admin UI::Header's title: its count - which links to the full index, when
        # there is one - what it counts, and a parenthetical.
        class Component < ApplicationComponent
          def initialize(count: nil, href: nil, suffix: nil, parenthetical: nil)
            @count = count
            @href = href
            @suffix = suffix
            @parenthetical = parenthetical
          end

          private

          def wrapped_parenthetical = safe_join(["(", @parenthetical, ")"])

          def count_display
            @href.present? ? link_to(number_display(@count), @href, class: "twlink") : number_display(@count)
          end
        end
      end
    end
  end
end
