# frozen_string_literal: true

module UI
  module ActiveLink
    # Adds "active" to the link's class on the page it points at. The browser decides, in
    # ui/active_link_controller.js, so a link rendered into a fragment cache doesn't carry the
    # answer for whichever page filled it. match: widens what counts as the page it points at —
    # the target's controller, or its controller and action, which is what a link carrying query
    # params (a search, a filtered index) needs. A caller that already knows the answer passes
    # active: rather than being routed around the component.
    class Component < ApplicationComponent
      MATCHES = [:path, :controller, :controller_action].freeze

      class << self
        # A menu whose manifest names its own active states translates them here, mapping each
        # onto a match. The matches map to themselves, so either vocabulary reaches the same
        # place and a renamed match takes its aliases with it.
        def match_table(**aliases)
          MATCHES.index_by(&:itself).merge(aliases).freeze
        end

        # A caller that needs the answer without a link — a menu picking out its current
        # entry — asks here rather than rendering one to find out
        def active?(path:, match:, view:)
          case match
          when :path then view.current_page_active?(path)
          when :controller then view.current_page_active?(path, true)
          else controller_action_match?(path, view)
          end
        end

        # The controller and action a URL resolves to. A link's doesn't depend on the request,
        # which is what lets the browser hold the comparison: it reads the page's own off the
        # body, and can't resolve a route itself.
        def route(url, verb = :get)
          recognized = Rails.application.routes.recognize_path(url, method: verb)
          "#{recognized[:controller]}##{recognized[:action]}"
        rescue ActionController::RoutingError
          nil
        end

        private

        # The request is recognized under its own verb: a page rendered by a failed PATCH
        # dispatched #update, and the GET route for that same URL is #show
        def controller_action_match?(path, view)
          target = route(path)
          target.present? && target == route(view.request.url, view.request.request_method)
        end
      end

      def initialize(path:, text: nil, active: nil, match: :path, html_class: nil, data: {}, **html_options)
        raise_if_invalid_value!(:match, match, MATCHES)
        # The component builds its own class, so a passed one is dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)

        @path = path
        @text = text
        @active = active
        @match = match
        @html_class = html_class
        @data = data
        @html_options = html_options
      end

      def call
        link_to(link_text, @path, **@html_options, class: link_class, data: link_data)
      end

      private

      # link_to labels a link with its own URL when the label is empty, so a caller that
      # forgot text: would ship an anchor reading "/o/example/dashboard"
      def link_text
        @text.presence || content.presence ||
          raise(ArgumentError, "text: or block content is required")
      end

      def link_class
        [@html_class, ("active" if @active)].compact.join(" ").presence
      end

      # A caller that passed active: has already answered, so the link goes out without a
      # controller to answer it again
      def link_data
        return @data unless @active.nil?

        @data.merge(controller: "ui--active-link", "ui--active-link-match-value": @match,
          "ui--active-link-route-value": (self.class.route(@path) unless @match == :path)).compact
      end
    end
  end
end
