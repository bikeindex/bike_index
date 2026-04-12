# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::Dropdown::Component.new(name: "Menu")) do |dropdown|
          dropdown.with_item { link_to "Profile", "#", class: "dropdown-link" }
          dropdown.with_item { link_to "Settings", "#", class: "dropdown-link" }
          dropdown.with_item { link_to "Logout", "#", class: "dropdown-link" }
        end
      end
    end
  end
end
