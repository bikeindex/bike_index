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

        # Enter submits the form when the listbox is closed
        def in_form
          {template: "ui/forms/combobox/component_preview/in_form"}
        end

        # Two-tone option content, mirrored onto the closed input by an overlay
        def rich_display
          {template: "ui/forms/combobox/component_preview/rich_display"}
        end

        # form-persist restores a draft selection over the rendered value
        def persisted
          {template: "ui/forms/combobox/component_preview/persisted"}
        end

        # rich_display: :stacked -- a muted second line, on a taller input
        def stacked
          {template: "ui/forms/combobox/component_preview/stacked"}
        end

        # Allows submitting a value that is not in the options list
        def free_text
          {template: "ui/forms/combobox/component_preview/free_text"}
        end

        # @!endgroup
      end
    end
  end
end
