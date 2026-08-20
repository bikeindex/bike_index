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
        render(UI::ActiveLink::Component.new(text: "Support", path: "/support", class: "twlink"))
      end

      # The path this scenario is served from — active, with no wider match needed
      def current_page
        render(UI::ActiveLink::Component.new(text: "This preview", path: "#{PREVIEW_PATH}/current_page",
          class: "twlink"))
      end

      # A different page of the same controller: active only because match: widens it
      def match_controller
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          match: :controller, class: "twlink"))
      end

      # The same link at the default match: :path, for the contrast
      def match_path
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          class: "twlink"))
      end

      # Ignores the query string, which match: :path wouldn't. Every scenario here shares one
      # controller and action, so what makes this narrower than :controller only shows in the spec
      def match_controller_action
        render(UI::ActiveLink::Component.new(text: "This scenario, other params",
          path: "#{PREVIEW_PATH}/match_controller_action?example=1",
          match: :controller_action, class: "twlink"))
      end

      # The path this scenario is served from, active only while the page carries no params of
      # its own — match: :path ignores them. Add ?example=1 to the URL to see the difference.
      def match_full_path
        render(UI::ActiveLink::Component.new(text: "This preview, exactly",
          path: "#{PREVIEW_PATH}/match_full_path", match: :full_path, class: "twlink"))
      end

      # A filter entry, which stands for the param it applies rather than for a URL: it points
      # away from its own filter, the way one already in force clears itself, and goes active
      # on the param alone. Add &page=2 to see a param it doesn't name ignored.
      def match_query
        render(UI::ActiveLink::Component.new(text: "Filter: on", path: "#{PREVIEW_PATH}/match_query",
          match: :query, query: {filter: "on"}, class: "twlink"))
      end

      # The entry a controller falls back to with the param absent, so "" is among its values
      def match_query_default
        render(UI::ActiveLink::Component.new(text: "Filter: off",
          path: "#{PREVIEW_PATH}/match_query_default?filter=off", match: :query,
          query: {filter: ["off", nil]}, class: "twlink"))
      end

      # Anything beyond class passes through to the anchor
      def with_html_options
        render(UI::ActiveLink::Component.new(text: "Opens in a new tab", path: "#{PREVIEW_PATH}/with_html_options",
          class: "twlink", id: "preview-active-link", target: "_blank"))
      end

      # Markup inside the link, in place of text:
      def with_block_content
        render(UI::ActiveLink::Component.new(path: "#{PREVIEW_PATH}/with_block_content", class: "twlink")) do
          tag.strong("Block content")
        end
      end
      # @!endgroup
    end
  end
end
