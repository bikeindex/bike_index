# frozen_string_literal: true

module Registrations
  module New
    module SectionLabel
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Registrations::New::SectionLabel::Component.new(text: "Bike info"))
        end

        def with_divider
          render(Registrations::New::SectionLabel::Component.new(text: "Your info", divider: true))
        end
      end
    end
  end
end
