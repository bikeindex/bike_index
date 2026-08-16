# frozen_string_literal: true

module PageBlock
  module Navbar
    module MenuLink
      # One menu manifest item, as an anchor
      class Component < ApplicationComponent
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
          render(UI::ActiveLink::Component.new(text: @label, path: @path, html_class: css_class,
            active: resolved_active, match_controller: @active == :match_controller, **@html_options))
        end

        private

        # :auto and :match_controller leave the current-page check to UI::ActiveLink
        def resolved_active
          @active unless [:auto, :match_controller].include?(@active)
        end

        def css_class
          ["nav-link", @link_class].compact.join(" ")
        end
      end
    end
  end
end
