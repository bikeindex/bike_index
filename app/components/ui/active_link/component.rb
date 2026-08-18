# frozen_string_literal: true

module UI
  module ActiveLink
    # Marks the link aria-current on the page it points at, which the is-active variant
    # (application.css) styles. match: widens what counts as that page — the target's controller,
    # or its controller and action, which is what a link carrying query params (a search, a
    # filtered index) needs. A caller that already knows the answer passes active: rather than
    # being routed around the component.
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

        private

        # Recognizing each end once yields both halves, where going through current_page_active?
        # first would recognize both again for the controller alone. The request is recognized
        # under its own verb: a page rendered by a failed PATCH dispatched #update, and the GET
        # route for that same URL is #show.
        def controller_action_match?(path, view)
          target = recognized(path)
          current = recognized(view.request.url, view.request.request_method)
          return false if target.nil? || current.nil?

          target[:controller] == current[:controller] && target[:action] == current[:action]
        end

        def recognized(url, verb = :get)
          Rails.application.routes.recognize_path(url, method: verb)
        rescue ActionController::RoutingError
          nil
        end
      end

      def initialize(path:, text: nil, active: nil, match: :path, html_class: nil, **html_options)
        raise_if_invalid_value!(:match, match, MATCHES)
        # html_class is what reaches the anchor, so a passed class would be dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)

        @path = path
        @text = text
        @active = active
        @match = match
        @html_class = html_class
        @html_options = html_options
      end

      def call
        link_to(link_text, @path, **@html_options.except(:aria), class: @html_class.presence, aria: aria_attributes)
      end

      private

      # link_to labels a link with its own URL when the label is empty, so a caller that
      # forgot text: would ship an anchor reading "/o/example/dashboard"
      def link_text
        @text.presence || content.presence ||
          raise(ArgumentError, "text: or block content is required")
      end

      def aria_attributes
        @html_options[:aria].to_h.merge(current: aria_current)
      end

      # "page" is reserved for the link whose own path is the current one. A widened match
      # means the current page sits inside what the link points at, not that it is it —
      # aria-current's "true", so a reader isn't told a link elsewhere is where it already is
      def aria_current
        return unless active?

        (@match == :path) ? "page" : "true"
      end

      def active?
        return @active unless @active.nil?

        self.class.active?(path: @path, match: @match, view: helpers)
      end
    end
  end
end
