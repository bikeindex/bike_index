# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Nav
        # The row an admin screen opens with: its heading, and the links and filters acting on
        # the whole screen right-aligned beside it. Block content is the list's items, so a
        # caller passes <li>s.
        class Component < ApplicationComponent
          BORDER_CLASSES = "tw:mb-6 tw:border-b tw:border-gray-300 tw:dark:border-gray-700"

          def initialize(title:, subtitle: nil, border: true)
            @title = title
            @subtitle = subtitle
            @border = border
          end

          private

          def wrapper_classes
            ["tw:flex tw:flex-row tw:flex-wrap tw:items-baseline tw:gap-x-4 tw:gap-y-2",
              (BORDER_CLASSES if @border)].compact.join(" ")
          end
        end
      end
    end
  end
end
