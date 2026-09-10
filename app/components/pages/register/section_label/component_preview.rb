# frozen_string_literal: true

module Pages
  module Register
    module SectionLabel
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Register::SectionLabel::Component.new(text: "Bike info"))
        end

        def with_divider
          render(Pages::Register::SectionLabel::Component.new(text: "Your info", divider: true))
        end
      end
    end
  end
end
