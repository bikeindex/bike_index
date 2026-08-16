# frozen_string_literal: true

module UI
  module ActiveLink
    # Adds "active" to the link's class on the page it points at; match_controller
    # widens that to any page of the target's controller. A caller that already knows
    # the answer passes active: rather than being routed around the component.
    class Component < ApplicationComponent
      def initialize(path:, text: nil, active: nil, match_controller: false, html_class: nil, **html_options)
        # The component builds its own class, so a passed one is dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)

        @path = path
        @text = text
        @active = active
        @match_controller = match_controller
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

        helpers.current_page_active?(@path, @match_controller)
      end
    end
  end
end
