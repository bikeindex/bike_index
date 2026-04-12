# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::Dropdown::Component.new(name: "Menu")) do |dropdown|
          dropdown.with_entry_item { helpers.link_to "Profile", "#" }
          dropdown.with_entry_item { helpers.link_to "Settings", "#" }
          dropdown.with_entry_divider
          dropdown.with_entry_item { helpers.link_to "Logout", "#" }
        end
      end
    end
  end
end
