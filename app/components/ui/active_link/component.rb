# frozen_string_literal: true

module UI
  module ActiveLink
    # Adds "active" to the link's class on the page it points at. match: widens what counts as
    # that page — the target's controller, or its controller and action, which is what a link
    # carrying query params (a search, a filtered index) needs. A caller that already knows the
    # answer passes active: rather than being routed around the component.
    class Component < ApplicationComponent
      MATCHES = [:path, :controller, :controller_action].freeze

      def initialize(path:, text: nil, active: nil, match: :path, html_class: nil, **html_options)
        raise_if_invalid_value!(:match, match, MATCHES)
        # The component builds its own class, so a passed one is dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)

        @path = path
        @text = text
        @active = active
        @match = match
        @html_class = html_class
        @html_options = html_options
      end

      def call
        link_to(@text || content, @path, **@html_options, class: link_class)
      end

      private

      def link_class
        [@html_class, ("active" if active?)].compact.join(" ").presence
      end

      def active?
        return @active unless @active.nil?

        case @match
        when :path then helpers.current_page_active?(@path)
        when :controller then helpers.current_page_active?(@path, true)
        else helpers.current_page_active?(@path, true) && actions_match?
        end
      end

      # current_page_active? has compared the controllers by here, memoizing the request's on
      # the view context, so this only adds the action
      def actions_match?
        routed_action(@path) == routed_action(helpers.request.url)
      end

      def routed_action(url)
        Rails.application.routes.recognize_path(url)[:action]
      rescue ActionController::RoutingError
        nil
      end
    end
  end
end
