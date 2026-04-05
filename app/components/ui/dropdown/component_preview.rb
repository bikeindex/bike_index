# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      def default
        options = [
          '<a href="#" class="dropdown-link">Profile</a>'.html_safe,
          '<a href="#" class="dropdown-link">Settings</a>'.html_safe,
          '<a href="#" class="dropdown-link">Logout</a>'.html_safe
        ]
        render(UI::Dropdown::Component.new(name: "Menu", options:))
      end
    end
  end
end
