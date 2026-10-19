# frozen_string_literal: true

module UI
  module Forms
    module Input
      class ComponentPreview < ApplicationComponentPreview
        def kinds
          {template: "ui/forms/input/component_preview/kinds"}
        end
      end
    end
  end
end
