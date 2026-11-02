# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Tabs
        class ComponentPreview < ApplicationComponentPreview
          # @!group Variants

          # A template, so the link can render UI::ButtonLink
          def default
            {template: "pages/admin/headers/tabs/component_preview/default", locals: {tabs:}}
          end

          # A template, so the alert can render UI::Alerts::Base
          def with_alert_and_summary
            {template: "pages/admin/headers/tabs/component_preview/with_alert_and_summary", locals: {tabs:}}
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
