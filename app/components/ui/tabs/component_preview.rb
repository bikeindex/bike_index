# frozen_string_literal: true

module UI
  module Tabs
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def default
        render(UI::Tabs::Component.new(nav_label: "Bike sections", tabs: [
          ComponentStructs::Shapes.tab("Show", "#", active: true),
          ComponentStructs::Shapes.tab("Edit", "#"),
          ComponentStructs::Shapes.tab("Duplicates", "#", count: 3)
        ]))
      end

      # Narrow the preview to see the row scroll rather than wrap, and the active tab
      # scrolled into view
      def many_tabs
        render(UI::Tabs::Component.new(nav_label: "Organization sections", tabs: [
          ComponentStructs::Shapes.tab("Show", "#"),
          ComponentStructs::Shapes.tab("Edit", "#"),
          ComponentStructs::Shapes.tab("Locations", "#", count: 2),
          ComponentStructs::Shapes.tab("Edit paid functionality", "#"),
          ComponentStructs::Shapes.tab("SSO", "#"),
          ComponentStructs::Shapes.tab("Invoices", "#"),
          ComponentStructs::Shapes.tab("Custom layouts", "#", active: true)
        ]))
      end
      # @!endgroup
    end
  end
end
