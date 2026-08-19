# frozen_string_literal: true

module UI
  module Forms
    module Input
      class ComponentPreview < ApplicationComponentPreview
        # @!group Kinds
        def text_field
          {template: "ui/forms/input/component_preview/text_field"}
        end

        def text_area
          {template: "ui/forms/input/component_preview/text_area"}
        end

        def datetime_local_field
          {template: "ui/forms/input/component_preview/datetime_local_field"}
        end
        # @!endgroup

        def prefix
          {template: "ui/forms/input/component_preview/prefix"}
        end
      end
    end
  end
end
