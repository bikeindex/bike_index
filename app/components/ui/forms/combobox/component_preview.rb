# frozen_string_literal: true

module UI
  module Forms
    module Combobox
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        # Plain string options, labeled by a UI::Forms::Group
        def default
          {template: "ui/forms/combobox/component_preview/default"}
        end

        # Hash options with separate display and submitted value
        def with_values
          {template: "ui/forms/combobox/component_preview/with_values"}
        end

        # Pre-selected value, listbox open on load
        def preselected
          {template: "ui/forms/combobox/component_preview/preselected"}
        end

        # Allows submitting a value that is not in the options list
        def free_text
          {template: "ui/forms/combobox/component_preview/free_text"}
        end

        # Inside a form, where the form builder ids the input and labels it
        def form_builder
          {template: "ui/forms/combobox/component_preview/form_builder"}
        end

        # @!endgroup
      end
    end
  end
end
