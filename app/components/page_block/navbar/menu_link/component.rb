# frozen_string_literal: true

module PageBlock
  module Navbar
    module MenuLink
      # One menu manifest item, as an anchor
      class Component < ApplicationComponent
        # :auto and :match_controller ship their rule to page-block--navbar, true and false
        # decide it here — see NavRoute for why the page can't be consulted
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
          link_to(@label, @path, **@html_options, class: css_class, data: data_attributes)
        end

        private

        def css_class
          ["nav-link", @link_class, ("active" if @active == true)].compact.join(" ")
        end

        def data_attributes
          @html_options.fetch(:data, {}).merge(active_data)
        end

        def active_data
          case @active
          when :auto then {active_path: true}
          when :match_controller then {active_routes: NavRoute.controller_for(@path)}
          else {}
          end
        end
      end
    end
  end
end
