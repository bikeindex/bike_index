# frozen_string_literal: true

module Form
  module RadioButtonGroup
    class ComponentPreview < ApplicationComponentPreview
      # @!group Examples
      def default
        render(Form::RadioButtonGroup::Component.new(
          name: :search_status,
          entries: [
            {value: "", label: "All"},
            {value: "active", label: "Active"},
            {value: "inactive", label: "Inactive"}
          ]
        ))
      end

      def with_selection
        render(Form::RadioButtonGroup::Component.new(
          name: :search_filter,
          selected: "active",
          entries: [
            {value: "", label: "All"},
            {value: "active", label: "Active"},
            {value: "inactive", label: "Inactive"}
          ]
        ))
      end
      # @!endgroup
    end
  end
end
