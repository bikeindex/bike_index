# frozen_string_literal: true

module UI
  module ButtonGroup
    class ComponentPreview < ApplicationComponentPreview
      # @!group Examples
      def default
        render(UI::ButtonGroup::Component.new(entries: [
          ComponentStructs::Shapes.entry("All", href: "#", active: true),
          ComponentStructs::Shapes.entry("Active", href: "#"),
          ComponentStructs::Shapes.entry("Inactive", href: "#")
        ]))
      end

      def with_html_labels
        render(UI::ButtonGroup::Component.new(entries: [
          ComponentStructs::Shapes.entry("All", href: "#"),
          ComponentStructs::Shapes.entry("only <strong>not</strong> impounded", href: "#", active: true),
          ComponentStructs::Shapes.entry("only <strong>impounded</strong>", href: "#")
        ]))
      end

      # An entry without an href renders a <button> — for a group that a Stimulus
      # controller handles rather than a navigation
      def buttons
        render(UI::ButtonGroup::Component.new(entries: [
          ComponentStructs::Shapes.entry("Map", active: true, data: {action: "click->something#show"}),
          ComponentStructs::Shapes.entry("List", data: {action: "click->something#show"})
        ]))
      end

      def with_disabled
        render(UI::ButtonGroup::Component.new(entries: [
          ComponentStructs::Shapes.entry("All", href: "#", active: true),
          ComponentStructs::Shapes.entry("Stolen", href: "#"),
          ComponentStructs::Shapes.entry("For sale", href: "#", disabled: true)
        ]))
      end

      def full_width
        render(UI::ButtonGroup::Component.new(full_width: true, entries: %w[xs s m l xl].map { |size|
          ComponentStructs::Shapes.entry(size.upcase, href: "#", active: size == "m")
        }))
      end
      # @!endgroup
    end
  end
end
