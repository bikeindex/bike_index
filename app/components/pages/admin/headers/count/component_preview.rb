# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Count
        class ComponentPreview < ApplicationComponentPreview
          # @!group Variants

          # Templates, so the count can render inside UI::Header
          def default
            {template: "pages/admin/headers/count/component_preview/default"}
          end

          def with_parenthetical
            {template: "pages/admin/headers/count/component_preview/with_parenthetical"}
          end

          # @!endgroup
        end
      end
    end
  end
end
