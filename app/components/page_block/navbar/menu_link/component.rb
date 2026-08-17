# frozen_string_literal: true

module PageBlock
  module Navbar
    module MenuLink
      # One menu manifest item, as an anchor
      class Component < ApplicationComponent
        # Nothing in the navbar is active at render — see NavRoute; false opts a link out
        ACTIVE_STATES = [:auto, :match_controller, false].freeze

        def initialize(label:, path:, active: :auto, link_class: nil, html_options: {})
          raise_if_invalid_value!(:active, active, ACTIVE_STATES)

          @label = label
          @path = path
          @active = active
          @link_class = link_class
          @html_options = html_options
        end

        def call
          link_to(@label, @path, **@html_options, class: css_class, data: data_attributes)
        end

        private

        def css_class
          ["nav-link", @link_class].compact.join(" ")
        end

        def data_attributes
          @html_options.fetch(:data, {}).merge(NavRoute.data(@active, @path))
        end
      end
    end
  end
end
