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
      # What a menu item hash can carry through to the link. The rest of an item is the menu's
      # own — its type, icon, children — and an absent key here takes initialize's default
      ITEM_KEYS = [:path, :match_paths, :match_params, :data, :id].freeze

      class << self
        # A menu manifest carries a link as a hash; what differs between the menus rendering
        # one is the class, and text: for a row whose label sits inside a block with its icon
        def from_item(item, html_class: nil, text: item[:label])
          new(**item.slice(*ITEM_KEYS), text:, class: html_class)
        end

        # The page a URL names — neither its origin nor its query is part of that. A query
        # arrives mid-pattern as well as at the end, since a route helper interpolated into
        # one carries the locale param. A URL with no path of its own points at a root —
        # someone else's, which the browser rules out on the origin.
        def page_path(url)
          url.to_s.sub(%r{\A[a-z]+://[^/]+}i, "").sub(%r{[?#][^/]*}, "").presence || "/"
        end

        # matchesPath in ui/active_link_controller.js, which answers this for a link itself.
        # The copy is for prose beside one — Admin::Navbar names the current page in the
        # picker, which no link can go active on its behalf.
        def covers?(pattern, path)
          pattern_segments = segments_of(pattern)
          path_segments = segments_of(path)
          stopped = pattern_segments.zip(path_segments).find do |segment, actual|
            segment == "**" || (segment != "*" && segment != actual)
          end
          return pattern_segments.length == path_segments.length if stopped.nil?

          stopped.first == "**"
        end

        private

        # Rails' current_page? ignores a trailing slash on either side
        def segments_of(path) = ((path.length > 1) ? path.delete_suffix("/") : path).split("/")
      end

      def initialize(path:, text: nil, match_paths: [], match_params: nil, data: {},
        **html_options)
        @match_paths = Array.wrap(match_paths.presence || path).map { |url| self.class.page_path(url) }
        @match_paths.each { |pattern| raise_if_invalid_pattern!(pattern) }
        @match_params = match_params.presence&.to_h { |param, values| [param, param_values(param, values)] }

        @path = path
        @text = text
        @data = data
        @html_options = html_options
      end

      def call
        link_to(link_text, @path, **@html_options, data: link_data)
      end

      private

      def raise_if_invalid_pattern!(pattern)
        raise ArgumentError, "match_paths: #{pattern} must start with /" unless pattern.start_with?("/")
        raise ArgumentError, "match_paths: ** only ends a pattern, not #{pattern}" if
          pattern.split("/")[0..-2].include?("**")
      end

      # A nil value is the param absent, which is "" once the browser reads it off the URL —
      # the same absence url_for writes by dropping the param, which is what the href beside
      # a filter entry's match_params does with it
      def param_values(param, values)
        listed = [values].flatten
        raise ArgumentError, "match_params: #{param} needs values" if listed.empty?

        listed.map(&:to_s)
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
          "ui--active-link-match-params-value": @match_params).compact
      end
    end
  end
end
