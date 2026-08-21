# frozen_string_literal: true

module UI
  module Tabs
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::Tabs::Component.new(nav_label: "Bike sections", tabs: [
          {label: "Show", href: "#", active: true},
          {label: "Edit", href: "#"},
          {label: "Duplicates", href: "#", count: 3}
        ]))
      end

      # Narrow the preview to see the row scroll, and each tab drop to its first letter
      def many_tabs
        render(UI::Tabs::Component.new(nav_label: "Organization sections", tabs: [
          {label: "Show", href: "#"},
          {label: "Edit", href: "#"},
          {label: "Locations", href: "#", count: 2},
          {label: "Edit paid functionality", href: "#"},
          {label: "SSO", href: "#"},
          {label: "Invoices", href: "#"},
          {label: "Custom layouts", href: "#", active: true}
        ]))
      end
    end
  end
end
