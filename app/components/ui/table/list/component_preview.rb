# frozen_string_literal: true

module UI
  module Table
    module List
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        def default
          {template: "ui/table/list/component_preview/default"}
        end

        def wide_definition
          {template: "ui/table/list/component_preview/wide_definition"}
        end

        # Long unbroken values in a panel narrower than they are
        def narrow
          {template: "ui/table/list/component_preview/narrow"}
        end

        # @!endgroup
      end
    end
  end
end
