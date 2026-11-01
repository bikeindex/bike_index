# frozen_string_literal: true

module Atoms
  module Admin
    module Headers
      module Section
        # A section of an admin record's tab, titled with its count - which links to the full
        # index. Block content follows the parenthetical.
        class Component < ApplicationComponent
          def initialize(title:, count:, href:, parenthetical: nil)
            @title = title
            @count = count
            @href = href
            @parenthetical = parenthetical
          end

          private

          def wrapped_parenthetical = safe_join(["(", @parenthetical, ")"])
        end
      end
    end
  end
end
