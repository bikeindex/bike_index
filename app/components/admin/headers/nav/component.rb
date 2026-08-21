# frozen_string_literal: true

module Admin
  module Headers
    module Nav
      # The row an admin screen opens with: its heading, and the links and filters acting on
      # the whole screen right-aligned beside it. Block content is the list's items, so a
      # caller passes <li>s.
      #
      # border: the rule under the row, off for a header drawing one of its own —
      # Admin::Headers::Tabs, whose tab row carries it.
      class Component < ApplicationComponent
        # The heading's mr-auto is what pushes this right; wrapped onto a line of its own it
        # starts at the left, which is the room a narrow screen has
        LIST_CLASSES = "tw:mb-0 tw:flex tw:list-none tw:flex-row tw:flex-wrap " \
          "tw:items-baseline tw:gap-1 tw:pl-0 tw:text-sm"

        # Keeps the pill .admin-subnav gave the .nav-links the un-migrated index views still
        # hand in — without it an active filter stops looking applied. `!` because
        # admin_unvendored outranks every utility
        LEGACY_ITEM_CLASSES = "tw:[&_a.nav-link]:rounded-md tw:[&_a.nav-link]:px-2! " \
          "tw:[&_a.nav-link]:py-1! tw:[&_a.nav-link]:no-underline " \
          "tw:[&_a.nav-link:hover]:bg-gray-100 tw:[&_a.nav-link.active]:bg-blue-600 " \
          "tw:[&_a.nav-link.active]:text-white"

        # The rule wants room on both sides of it; a row without one only has to clear itself
        BORDER_CLASSES = "tw:mb-6 tw:border-b tw:border-gray-300 tw:pb-4 tw:dark:border-gray-700"

        def initialize(title:, subtitle: nil, border: true)
          @title = title
          @subtitle = subtitle
          @border = border
        end

        private

        def wrapper_classes
          ["tw:flex tw:flex-row tw:flex-wrap tw:items-baseline tw:gap-x-4 tw:gap-y-2",
            @border ? BORDER_CLASSES : "tw:mb-4"].join(" ")
        end

        def list_classes = "#{LIST_CLASSES} #{LEGACY_ITEM_CLASSES}"
      end
    end
  end
end
