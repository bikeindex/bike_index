# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Tabs
        class ComponentPreview < ApplicationComponentPreview
          # @!group Variants

          # A template, so the links and the alert can render UI:: components
          def default
            {template: "pages/admin/headers/tabs/component_preview/default", locals: {tabs:}}
          end

          def with_summary
            render(Pages::Admin::Headers::Tabs::Component.new(title: "Brakebills", tabs:, nav_label: "Organization sections")) do |header|
              header.with_summary { "A school in upstate New York" }
            end
          end

          # @!endgroup

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
