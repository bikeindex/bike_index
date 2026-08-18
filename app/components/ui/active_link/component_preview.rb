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
        render(UI::ActiveLink::Component.new(text: "Support", path: "/support", html_class: "twlink"))
      end

      # The path this scenario is served from — active, with no match_controller needed
      def current_page
        render(UI::ActiveLink::Component.new(text: "This preview", path: "#{PREVIEW_PATH}/current_page",
          html_class: "twlink"))
      end

      # A different page of the same controller: active only because match: widens it
      def match_controller
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          match: :controller, html_class: "twlink"))
      end

      # The same link at the default match: :path, for the contrast
      def match_path
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          html_class: "twlink"))
      end

      # Ignores the query string, which match: :path wouldn't. Every scenario here shares one
      # controller and action, so what makes this narrower than :controller only shows in the spec
      def match_controller_action
        render(UI::ActiveLink::Component.new(text: "This scenario, other params",
          path: "#{PREVIEW_PATH}/match_controller_action?example=1",
          match: :controller_action, html_class: "twlink"))
      end

      # A caller that already knows the state passes active:, skipping the current-page check
      def active_forced
        render(UI::ActiveLink::Component.new(text: "Forced active", path: "/support",
          active: true, html_class: "twlink"))
      end

      # Anything beyond html_class passes through to the anchor
      def with_html_options
        render(UI::ActiveLink::Component.new(text: "Opens in a new tab", path: "#{PREVIEW_PATH}/with_html_options",
          html_class: "twlink", id: "preview-active-link", target: "_blank"))
      end

      # Markup inside the link, in place of text:
      def with_block_content
        render(UI::ActiveLink::Component.new(path: "#{PREVIEW_PATH}/with_block_content", html_class: "twlink")) do
          tag.strong("Block content")
        end
      end
      # @!endgroup
    end
  end
end
