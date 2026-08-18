# frozen_string_literal: true

module PageBlock
  module Navbar
    module MenuLink
      # One menu manifest item, as an anchor
      class Component < ApplicationComponent
        def initialize(label:, path:, match: :path, link_class: nil, html_options: {})
          @label = label
          @path = path
          @match = match
          @link_class = link_class
          @html_options = html_options
        end

        def call
          render(UI::ActiveLink::Component.new(text: @label, path: @path, match: @match,
            html_class: css_class, **@html_options))
        end

        private

        def css_class
          ["nav-link", @link_class].compact.join(" ")
        end
      end
    end
  end
end
