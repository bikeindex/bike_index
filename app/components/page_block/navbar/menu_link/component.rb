# frozen_string_literal: true

module PageBlock
  module Navbar
    module MenuLink
      # One menu manifest item, as an anchor
      class Component < ApplicationComponent
        def initialize(label:, path:, active: nil, link_class: nil, html_options: {})
          @label = label
          @path = path
          @active = active
          @link_class = link_class
          @html_options = html_options
        end

        def call
          options = {class: css_class, **@html_options}
          case @active
          when nil, :match_controller
            helpers.active_link(@label, @path, match_controller: @active == :match_controller, **options)
          else
            link_to(@label, @path, **options)
          end
        end

        private

        def css_class
          ["nav-link", @link_class, ("active" if @active == true)].compact.join(" ")
        end
      end
    end
  end
end
