# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::Dropdown::Component.new(name: "Menu")) do |dropdown|
          dropdown.with_item { helpers.link_to "Profile", "#" }
          dropdown.with_item { helpers.link_to "Settings", "#" }
          dropdown.with_divider
          dropdown.with_item { helpers.link_to "Logout", "#" }
        end
      end
    end
  end
end
