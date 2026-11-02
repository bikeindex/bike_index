# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Count
        # Goes after an admin UI::Header's title: its count - which links to the full index, when
        # there is one - and a parenthetical. The weight undoes the heading's.
        class Component < ApplicationComponent
          def initialize(count: nil, href: nil, parenthetical: nil)
            @count = count
            @href = href
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
