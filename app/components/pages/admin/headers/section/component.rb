# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Section
        # A section of an admin record's tab, titled with its count - which links to the full
        # index, when there is one. Block content follows the parenthetical.
        class Component < ApplicationComponent
          def initialize(title:, count:, href: nil, parenthetical: nil)
            @title = title
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
