# frozen_string_literal: true

module UI
  module ActiveLink
    # Marks the link aria-current on the page it points at, which the is-active variant
    # (application.css) styles. The browser decides, in ui/active_link_controller.js, so a link
    # rendered into a fragment cache doesn't carry the answer for whichever page filled it.
    # match: widens or narrows what counts as the page it points at: its query string too, or
    # only its controller, or its controller and action — which is what a link carrying query
    # params (a search, a filtered index) needs. :query is for a filter entry, which stands for
    # the params it applies rather than for a URL — see query: below.
    class Component < ApplicationComponent
      MATCHES = [:path, :full_path, :controller, :controller_action, :query].freeze
      # The matches the browser answers with a route rather than with the URL
      ROUTE_MATCHES = [:controller, :controller_action].freeze

      # A menu manifest — UserServices::MenuItemsOrg's or MenuItemsAccount's — carries a link as
      # a hash, and every menu rendering one turns it into this component the same way. What
      # differs is the class, and text: for a row whose label sits inside a block with its icon.
      def self.from_item(item, html_class: nil, text: item[:label])
        new(path: item[:path], text:, match: item[:match] || :path,
          matching_controllers: item[:matching_controllers] || [], data: item[:data] || {},
          id: item[:id], class: html_class)
      end

      def initialize(path:, text: nil, match: :path, matching_controllers: [], query: {}, data: {},
        **html_options)
        raise_if_invalid_value!(:match, match, MATCHES)
        # Only a :controller match compares controllers, so anywhere else these would be
        # compared against a controller#action and never hit
        raise ArgumentError, "matching_controllers: needs match: :controller" if
          matching_controllers.any? && match != :controller
        raise ArgumentError, "query: and match: :query go together" if query.any? != (match == :query)

        @path = path
        @text = text
        @match = match
        @matching_controllers = matching_controllers
        @query = query
        @data = data
        @html_options = html_options
      end

      def call
        link_to(link_text, @path, **@html_options, data: link_data)
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
          "ui--active-link-query-value": link_query).compact
      end

      # Each param the entry applies, and the values of it that mean the entry is the one in
      # force. A nil among those values is the entry a controller falls back to with the param
      # absent, which is "" once the browser reads the param off the URL
      def link_query
        return unless @match == :query

        @query.to_h { |param, values| [param, (values.is_a?(Array) ? values : [values]).map(&:to_s)] }
          .to_json
      end

      # What the browser compares the page against — it can't resolve a route itself. One
      # controller#action, or one controller per entry when that's what the match compares,
      # so a menu entry whose section spans two of them lists the other too.
      def link_routes
        return unless @match.in?(ROUTE_MATCHES)

        [route(@path), *@matching_controllers].compact.join(" ").presence
      end

      def route(url)
        recognized = Rails.application.routes.recognize_path(url)
        return recognized[:controller] if @match == :controller

        "#{recognized[:controller]}##{recognized[:action]}"
      rescue ActionController::RoutingError
        nil
      end
    end
  end
end
