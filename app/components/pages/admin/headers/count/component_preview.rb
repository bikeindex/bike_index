# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Count
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(UI::Header::Component.new(tag: :h2)) do
              safe_join(["Notifications", render(Pages::Admin::Headers::Count::Component.new(count: 12, href: "#"))])
            end
          end

          def with_parenthetical
            render(UI::Header::Component.new(tag: :h2)) do
              safe_join(["Bikes", render(Pages::Admin::Headers::Count::Component.new(count: 250, href: "#", parenthetical: "first 100 shown"))])
            end
          end
        end
      end
    end
  end
end
