# frozen_string_literal: true

module PageBlock
  module Navbar
    module MenuLink
      # One menu manifest item, as an anchor
      class Component < ApplicationComponent
        # :auto and :match_controller resolve through UI::ActiveLink, true and false decide it here
        ACTIVE_STATES = [:auto, :match_controller, true, false].freeze

        def initialize(label:, path:, active: :auto, link_class: nil, html_options: {})
          raise_if_invalid_value!(:active, active, ACTIVE_STATES)

          @label = label
          @path = path
          @active = active
          @link_class = link_class
          @html_options = html_options
        end

        def call
          case @active
          when :auto, :match_controller
            render(UI::ActiveLink::Component.new(text: @label, path: @path, html_class: css_class,
              match_controller: @active == :match_controller, **@html_options))
          else
            link_to(@label, @path, class: [css_class, ("active" if @active)].compact.join(" "), **@html_options)
          end
        end

        private

        def css_class
          ["nav-link", @link_class].compact.join(" ")
        end
      end
    end
  end
end
