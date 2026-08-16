# frozen_string_literal: true

module UI
  module ActiveLink
    # Adds "active" to the link's class on the page it points at; match_controller
    # widens that to any page of the target's controller
    class Component < ApplicationComponent
      def initialize(path:, text: nil, match_controller: false, html_class: nil, **html_options)
        @path = path
        @text = text
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
        helpers.current_page_active?(@path, @match_controller)
      end
    end
  end
end
