# frozen_string_literal: true

module UI
  module ActiveLink
    class ComponentPreview < ApplicationComponentPreview
      # Every scenario is a segment of this, so a pattern below covers its siblings
      PREVIEW_PATH = "/rails/view_components/ui/active_link/component"

      # @!group Variants
      # Points at another page, so it stays a plain link
      def default
        render(UI::ActiveLink::Component.new(text: "Support", path: "/support", class: "twlink"))
      end

      # The path this scenario is served from — active, with nothing wider to cover
      def current_page
        render(UI::ActiveLink::Component.new(text: "This preview", path: "#{PREVIEW_PATH}/current_page",
          class: "twlink"))
      end

      # A sibling scenario, covered because ** takes every path below the group's own
      def match_paths_below
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          match_paths: "#{PREVIEW_PATH}/**", class: "twlink"))
      end

      # The same link with match_paths: left out, for the contrast
      def match_paths_default
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          class: "twlink"))
      end

      # A pattern names a page rather than the link, so it can name the one being served —
      # which the link still only covers, since it points somewhere else
      def match_paths_other_page
        render(UI::ActiveLink::Component.new(text: "A sibling preview", path: "#{PREVIEW_PATH}/default",
          match_paths: "#{PREVIEW_PATH}/match_paths_other_page", class: "twlink"))
      end

      # A single * stands for one segment, so a pattern can leave one variable in the middle
      def match_paths_one_segment
        render(UI::ActiveLink::Component.new(text: "This preview, through a wildcard segment",
          path: "#{PREVIEW_PATH}/match_paths_one_segment", class: "twlink",
          match_paths: "/rails/view_components/ui/active_link/*/match_paths_one_segment"))
      end

      # A filter entry, which stands for the param it applies rather than for a URL: it points
      # away from its own filter, the way one already in force clears itself, and goes active
      # on the param alone. Add &page=2 to see a param it doesn't name ignored.
      def match_params
        render(UI::ActiveLink::Component.new(text: "Filter: on", path: "#{PREVIEW_PATH}/match_params",
          match_params: {filter: "on"}, class: "twlink"))
      end

      # The entry a controller falls back to with the param absent, so BLANK is among its values
      def match_params_blank
        render(UI::ActiveLink::Component.new(text: "Filter: off",
          path: "#{PREVIEW_PATH}/match_params_blank?filter=off",
          match_params: {filter: ["off", UI::ActiveLink::Component::BLANK]}, class: "twlink"))
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
