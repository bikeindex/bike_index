# frozen_string_literal: true

module UI
  module Forms
    module RadioButtonGroup
      class ComponentPreview < ApplicationComponentPreview
        # @!group Examples
        def default
          render(UI::Forms::RadioButtonGroup::Component.new(
            name: :search_status,
            entries: [
              {value: "", label: "All"},
              {value: "active", label: "Active"},
              {value: "inactive", label: "Inactive"}
            ]
          ))
        end

        def with_html_labels
          render(UI::Forms::RadioButtonGroup::Component.new(
            name: :search_impounded,
            entries: [
              {value: "", label: "All"},
              {value: "not_impounded", label: "only <strong>not</strong> impounded"},
              {value: "impounded", label: "only <strong>impounded</strong>"}
            ]
          ))
        end

        def with_selection
          render(UI::Forms::RadioButtonGroup::Component.new(
            name: :search_filter,
            selected: "active",
            entries: [
              {value: "", label: "All"},
              {value: "active", label: "Active"},
              {value: "inactive", label: "Inactive"}
            ]
          ))
        end

        def full_width
          render(UI::Forms::RadioButtonGroup::Component.new(
            name: :frame_size,
            full_width: true,
            selected: "m",
            entries: %w[xs s m l xl].map { |size| {value: size, label: size.upcase} }
          ))
        end
        # @!endgroup
      end
    end
  end
end
