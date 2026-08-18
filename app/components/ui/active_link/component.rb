# frozen_string_literal: true

module UI
  module ActiveLink
    # Marks the link aria-current on the page it points at, which the is-active variant
    # (application.css) styles. The browser decides, in ui/active_link_controller.js, so a link
    # rendered into a fragment cache doesn't carry the answer for whichever page filled it.
    # match: widens or narrows what counts as the page it points at: its query string too, or
    # everything but a search of it, or only its controller, or its controller and action —
    # which is what a link carrying query params (a search, a filtered index) needs.
    class Component < ApplicationComponent
      MATCHES = [:path, :full_path, :unfiltered_path, :controller, :controller_action].freeze
      # The matches the browser answers with a route rather than with the URL
      ROUTE_MATCHES = [:controller, :controller_action].freeze
      # What sortable_search_params? counts as a search, for :unfiltered_path to ask in the
      # browser. period is the exception it makes for itself: only a period other than "all"
      # narrows the page, so the controller reads that one's value rather than its presence.
      FILTER_PARAMS = (Binxtils::SortableHelper::BASE_SEARCH_KEYS +
        Binxtils::SortableHelper.extra_search_keys)
        .flat_map { |key| key.is_a?(Hash) ? key.keys : [key] }
        .-(%i[direction sort period per_page]).map(&:to_s).freeze

      def initialize(path:, text: nil, match: :path, matching_controllers: [], html_class: nil,
        data: {}, **html_options)
        raise_if_invalid_value!(:match, match, MATCHES)
        # html_class is what reaches the anchor, so a passed class would be dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)

        @path = path
        @text = text
        @match = match
        @matching_controllers = matching_controllers
        @html_class = html_class
        @data = data
        @html_options = html_options
      end

      def call
        link_to(link_text, @path, **@html_options, class: @html_class.presence, data: link_data)
      end

      private

      # link_to labels a link with its own URL when the label is empty, so a caller that
      # forgot text: would ship an anchor reading "/o/example/dashboard"
      def link_text
        @text.presence || content.presence ||
          raise(ArgumentError, "text: or block content is required")
      end

      def link_data
        @data.merge(controller: [@data[:controller], "ui--active-link"].compact.join(" "),
          "ui--active-link-match-value": @match,
          "ui--active-link-routes-value": link_routes,
          "ui--active-link-filters-value": link_filters).compact
      end

      def link_filters
        FILTER_PARAMS.join(" ") if @match == :unfiltered_path
      end

      # The link's own route, which the browser compares the page's against — it can't resolve
      # one itself. A menu entry whose section spans two controllers lists the other too.
      def link_routes
        return unless @match.in?(ROUTE_MATCHES)

        [route(@path), *@matching_controllers].compact.join(" ").presence
      end

      def route(url)
        recognized = Rails.application.routes.recognize_path(url)
        "#{recognized[:controller]}##{recognized[:action]}"
      rescue ActionController::RoutingError
        nil
      end
    end
  end
end
