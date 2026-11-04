# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Stories
      # "Load more" nests each page's frame inside the one before it, so a click swaps the
      # button's frame for the next page's stories - plus the frame for the page after
      class Component < ApplicationComponent
        PER_PAGE = 9
        PURPLE_OUTLINE = "tw:border-2! tw:border-purple-500! tw:normal-case! tw:text-purple-500! tw:hover:bg-purple-500! tw:hover:text-white!"

        def initialize(recovery_displays:, pagy:)
          @recovery_displays = recovery_displays
          @pagy = pagy
        end

        private

        def link_label(link) = link.sub(%r{\Ahttps?://(www\.)?}, "").truncate(41)

        def page_path(page) = recovery_stories_path(page:, per_page: (@pagy.limit unless @pagy.limit == PER_PAGE))
      end
    end
  end
end
