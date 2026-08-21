# frozen_string_literal: true

module UI
  module Tabs
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def default
        render(UI::Tabs::Component.new(nav_label: "Bike sections", tabs: [
          {label: "Show", href: "#", active: true},
          {label: "Edit", href: "#"},
          {label: "Duplicates", href: "#", count: 3}
        ]))
      end

      # Narrow the preview to see the row scroll rather than wrap, and the active tab
      # scrolled into view
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
      # @!endgroup
    end
  end
end
