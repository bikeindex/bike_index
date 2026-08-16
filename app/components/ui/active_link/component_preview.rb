# frozen_string_literal: true

module UI
  module ActiveLink
    class ComponentPreview < ApplicationComponentPreview
      # Every scenario routes through one controller, so the match_controller pair below
      # differs on a path neither is served from
      PREVIEW_PATH = "/rails/view_components/ui/active_link/component"

      # @!group Variants
      # Points at another page, so it stays a plain link
      def default
        render(UI::ActiveLink::Component.new(text: "Support", path: "/support", html_class: "nav-link"))
      end

      # The path this scenario is served from — active, with no match_controller needed
      def current_page
        render(UI::ActiveLink::Component.new(text: "This preview", path: "#{PREVIEW_PATH}/current_page",
          html_class: "nav-link"))
      end

      # A different page of the same controller: active only because match_controller widens the match
      def match_controller
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          match_controller: true, html_class: "nav-link"))
      end

      # The same link without match_controller, for the contrast
      def match_controller_omitted
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          html_class: "nav-link"))
      end

      # A caller that already knows the state passes active:, skipping the current-page check
      def active_forced
        render(UI::ActiveLink::Component.new(text: "Forced active", path: "/support",
          active: true, html_class: "nav-link"))
      end

      # Anything beyond html_class passes through to the anchor
      def with_html_options
        render(UI::ActiveLink::Component.new(text: "Opens in a new tab", path: "#{PREVIEW_PATH}/with_html_options",
          html_class: "twlink", id: "preview-active-link", target: "_blank"))
      end

      # Markup inside the link, in place of text:
      def with_block_content
        render(UI::ActiveLink::Component.new(path: "#{PREVIEW_PATH}/with_block_content", html_class: "nav-link")) do
          tag.strong("Block content")
        end
      end
      # @!endgroup
    end
  end
end
