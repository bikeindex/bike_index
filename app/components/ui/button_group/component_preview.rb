# frozen_string_literal: true

module UI
  module ButtonGroup
    class ComponentPreview < ApplicationComponentPreview
      # @!group Examples
      def default
        render(UI::ButtonGroup::Component.new(entries: [
          {label: "All", href: "#", active: true},
          {label: "Active", href: "#"},
          {label: "Inactive", href: "#"}
        ]))
      end

      def with_html_labels
        render(UI::ButtonGroup::Component.new(entries: [
          {label: "All", href: "#"},
          {label: "only <strong>not</strong> impounded", href: "#", active: true},
          {label: "only <strong>impounded</strong>", href: "#"}
        ]))
      end

      # An entry without an href renders a <button> — for a group that a Stimulus
      # controller handles rather than a navigation
      def buttons
        render(UI::ButtonGroup::Component.new(entries: [
          {label: "Map", active: true, data: {action: "click->something#show"}},
          {label: "List", data: {action: "click->something#show"}}
        ]))
      end

      def with_disabled
        render(UI::ButtonGroup::Component.new(entries: [
          {label: "All", href: "#", active: true},
          {label: "Stolen", href: "#"},
          {label: "For sale", href: "#", disabled: true}
        ]))
      end

      def full_width
        render(UI::ButtonGroup::Component.new(full_width: true,
          entries: %w[xs s m l xl].map { |size| {label: size.upcase, href: "#", active: size == "m"} }))
      end
      # @!endgroup
    end
  end
end
