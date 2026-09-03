# frozen_string_literal: true

module UI
  module Forms
    module Checkbox
      class ComponentPreview < ApplicationComponentPreview
        # @!group Examples
        def default
          render(UI::Forms::Checkbox::Component.new(name: :subscribe, label: "Email me updates"))
        end

        def checked
          render(UI::Forms::Checkbox::Component.new(name: :subscribe, label: "Email me updates", checked: true))
        end

        def form_builder
          {template: "ui/forms/checkbox/component_preview/form_builder"}
        end
        # @!endgroup
      end
    end
  end
end
