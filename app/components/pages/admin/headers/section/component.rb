# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Section
        # A section of an admin record's tab, titled with its count - which links to the full
        # index, when there is one. A section that isn't a list, like an edit form, has no count.
        # Block content follows the parenthetical.
        class Component < ApplicationComponent
          def initialize(title:, count: nil, href: nil, parenthetical: nil, margin_classes: "tw:mt-6 tw:mb-3 tw:first:mt-0")
            @title = title
            @count = count
            @href = href
            @parenthetical = parenthetical
            @margin_classes = margin_classes
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
