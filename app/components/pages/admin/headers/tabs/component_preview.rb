# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Tabs
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Admin::Headers::Tabs::Component.new(title: "Brakebills", tabs:, nav_label: "Organization sections"))
          end

          def with_summary
            render(Pages::Admin::Headers::Tabs::Component.new(title: "Brakebills", tabs:, nav_label: "Organization sections")) do |header|
              header.with_summary { content_tag(:p, "A school in upstate New York") }
            end
          end

          # A template, so the links and the alert can render UI:: components
          def with_links_and_alert
            render_with_template(template: "pages/admin/headers/tabs/component_preview/with_links_and_alert", locals: {tabs:})
          end

          private

          def tabs
            [ComponentStructs::Shapes.tab("Show", "#", active: true),
              ComponentStructs::Shapes.tab("Edit", "#"),
              ComponentStructs::Shapes.tab("Locations", "#", count: 2)]
          end
        end
      end
    end
  end
end
