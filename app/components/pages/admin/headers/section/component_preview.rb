# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Section
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Admin::Headers::Section::Component.new(title: "Notifications", count: 12, href: "#"))
          end

          def without_count
            render(Pages::Admin::Headers::Section::Component.new(title: "Edit Promoted Alert"))
          end

          def within_a_section
            render(Pages::Admin::Headers::Section::Component.new(title: "Ban information", tag: :h3))
          end

          def with_parenthetical
            render(Pages::Admin::Headers::Section::Component.new(title: "Bikes", count: 250, href: "#",
              parenthetical: "first 100 shown"))
          end
        end
      end
    end
  end
end
