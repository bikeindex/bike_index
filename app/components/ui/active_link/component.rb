# frozen_string_literal: true

module UI
  module ActiveLink
    # Marks the link aria-current on the page it covers, which the is-active variant
    # (application.css) styles. The browser decides, in ui/active_link_controller.js, so a link
    # rendered into a fragment cache doesn't carry the answer for whichever page filled it.
    # match_paths: widens what it covers past its own href, as one pattern or a list of them —
    # "*" stands for one segment and a trailing "**" for the rest, so a section's sub-pages
    # count. match_params: narrows it to the pages carrying those params, which is what a filter
    # entry needs: it stands for the params it applies rather than for a URL, and links away
    # from itself to clear them.
    class Component < ApplicationComponent
      # The value a controller reads as its default whether the URL omits the param or
      # leaves it empty
      BLANK = "blank"

      # What a menu item hash can carry through to the link. The rest of an item is the menu's
      # own — its type, icon, children — and an absent key here takes initialize's default
      ITEM_KEYS = [:path, :match_paths, :match_params, :exact_params, :data, :id].freeze

      # A menu manifest carries a link as a hash; what differs between the menus rendering one
      # is the class, and text: for a row whose label sits inside a block with its icon
      def self.from_item(item, html_class: nil, text: item[:label])
        new(**item.slice(*ITEM_KEYS), text:, class: html_class)
      end

      def initialize(path:, text: nil, match_paths: [], match_params: nil, exact_params: false,
        data: {}, **html_options)
        @match_paths = Array.wrap(match_paths.presence || path).map { |url| page_path(url) }
        @match_params = match_params.presence
        @match_paths.each { |pattern| raise_if_invalid_pattern!(pattern) }
        @match_params&.each { |param, values| raise_if_invalid_values!(param, values) }

        @path = path
        @text = text
        @exact_params = exact_params
        @data = data
        @html_options = html_options
      end

      def call
        link_to(link_text, @path, **@html_options, data: link_data)
      end

      private

      # A match_paths: entry is a pattern for a page rather than a URL, so an origin, query and
      # anchor are no part of one. They arrive mid-pattern as well as at the end, since a route
      # helper interpolated into a pattern carries the locale param. A URL with no path of its
      # own points at a root — someone else's, which the browser rules out on the origin.
      def page_path(url)
        url.to_s.sub(%r{\A[a-z]+://[^/]+}i, "").sub(%r{[?#][^/]*}, "").presence || "/"
      end

      def raise_if_invalid_pattern!(pattern)
        raise ArgumentError, "match_paths: #{pattern} must start with /" unless pattern.start_with?("/")
        raise ArgumentError, "match_paths: ** only ends a pattern, not #{pattern}" if
          pattern.split("/")[0..-2].include?("**")
      end

      # nil is the habit BLANK replaces — it would render no values at all, and so quietly
      # never match
      def raise_if_invalid_values!(param, values)
        wrapped = Array.wrap(values)
        return if wrapped.any? && wrapped.all?(&:present?)

        raise ArgumentError, "match_params: #{param} needs values — #{BLANK} for an absent one"
      end

      # link_to labels a link with its own URL when the label is empty, so a caller that
      # forgot text: would ship an anchor reading "/o/example/dashboard"
      def link_text
        @text.presence || content.presence ||
          raise(ArgumentError, "text: or block content is required")
      end

      def link_data
        @data.merge(controller: [@data[:controller], "ui--active-link"].compact.join(" "),
          "ui--active-link-match-paths-value": @match_paths.join(" "),
          "ui--active-link-match-params-value": link_params,
          "ui--active-link-exact-params-value": (true if @exact_params)).compact
      end

      def link_params
        @match_params&.transform_values { |values| Array.wrap(values).map(&:to_s) }
      end
    end
  end
end
