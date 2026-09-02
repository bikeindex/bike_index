# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Nav
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Admin::Headers::Nav::Component.new(title: "Manage Organizations"))
          end

          def with_subtitle
            render(Pages::Admin::Headers::Nav::Component.new(title: "Brakebills", subtitle: "Editing paid functionality"))
          end

          # A template, so the items can render UI:: components
          def with_items
            {template: "pages/admin/headers/nav/component_preview/with_items"}
          end

          def without_border
            render(Pages::Admin::Headers::Nav::Component.new(title: "Brakebills", border: false))
          end
        end
      end
    end
  end
end
