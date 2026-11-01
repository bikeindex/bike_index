# frozen_string_literal: true

module Atoms
  module Admin
    module Headers
      module Section
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Atoms::Admin::Headers::Section::Component.new(title: "Notifications", count: 12, href: "#"))
          end

          def with_parenthetical
            render(Atoms::Admin::Headers::Section::Component.new(title: "Bikes", count: 250, href: "#",
              parenthetical: "first 100 shown"))
          end
        end
      end
    end
  end
end
