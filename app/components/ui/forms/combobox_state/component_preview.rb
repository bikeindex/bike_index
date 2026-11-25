# frozen_string_literal: true

module UI
  module Forms
    module ComboboxState
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        def default
          render(UI::Forms::ComboboxState::Component.new(html_options: {placeholder: "Select your state"}))
        end

        def preselected
          render(UI::Forms::ComboboxState::Component.new(name: :preselected_state, html_options: {value: "CO"}))
        end

        # @!endgroup
      end
    end
  end
end
