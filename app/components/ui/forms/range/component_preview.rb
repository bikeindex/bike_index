# frozen_string_literal: true

module UI
  module Forms
    module Range
      class ComponentPreview < ApplicationComponentPreview
        # @!group Examples
        def default
          render(UI::Forms::Range::Component.new(name: :geometry, label: "Geometry", value: 4, max: 5))
        end

        def with_end_labels
          render(UI::Forms::Range::Component.new(name: :year, label: "Year", value: 2, max: 5, min_label: "Ignore year",
            max_label: "Only same year"))
        end

        def fractional_steps
          render(UI::Forms::Range::Component.new(name: :ratio, label: "Stack to reach", value: 1.4, min: 1, max: 2, step: 0.05))
        end
        # @!endgroup
      end
    end
  end
end
