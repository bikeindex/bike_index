# frozen_string_literal: true

module Admin
  module Headers
    module Nav
      # The row an admin screen opens with: its heading, and the links and filters acting on
      # the whole screen right-aligned beside it. Block content is the list's items, so a
      # caller passes <li>s.
      class Component < ApplicationComponent
        # The rule wants room on both sides of it; a row without one only has to clear itself
        BORDER_CLASSES = "tw:mb-6 tw:border-b tw:border-gray-300 tw:pb-4 tw:dark:border-gray-700"

        def initialize(title:, subtitle: nil, border: true)
          @title = title
          @subtitle = subtitle
          @border = border
        end

        private

        def wrapper_classes
          ["tw:mt-6 tw:flex tw:flex-row tw:flex-wrap tw:items-baseline tw:gap-x-4 tw:gap-y-2",
            @border ? BORDER_CLASSES : "tw:mb-4"].join(" ")
        end
      end
    end
  end
end
