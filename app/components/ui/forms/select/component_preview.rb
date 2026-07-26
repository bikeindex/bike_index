# frozen_string_literal: true

module UI
  module Forms
    module Select
      class ComponentPreview < ApplicationComponentPreview
        # @!group Examples
        def default
          {template: "ui/forms/select/component_preview/default"}
        end

        def with_blank
          {template: "ui/forms/select/component_preview/with_blank"}
        end
        # @!endgroup
      end
    end
  end
end
