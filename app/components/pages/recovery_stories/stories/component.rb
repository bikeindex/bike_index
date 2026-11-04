# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Stories
      # "Load more" nests each page's frame inside the one before it, so a click swaps the
      # button's frame for the next page's stories - plus the frame for the page after
      class Component < ApplicationComponent
        PER_PAGE = 9
        CARD_CLASSES = "tw:flex tw:flex-col tw:overflow-hidden tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white tw:text-gray-700 tw:no-underline tw:transition-all tw:duration-300 tw:dark:border-gray-700 tw:dark:bg-gray-800 tw:dark:text-gray-200"
        LINKED_CARD_CLASSES = "tw:hover:-translate-y-1.25 tw:hover:text-gray-700 tw:dark:hover:text-gray-200"
        PURPLE_OUTLINE = "tw:border-2! tw:border-purple-500! tw:normal-case! tw:text-purple-500! tw:hover:bg-purple-500! tw:hover:text-white!"

        def initialize(recovery_displays:, pagy:)
          @recovery_displays = recovery_displays
          @pagy = pagy
        end

        private

        def page_path(page) = recovery_stories_path(page:, per_page: (@pagy.limit unless @pagy.limit == PER_PAGE))
      end
    end
  end
end
