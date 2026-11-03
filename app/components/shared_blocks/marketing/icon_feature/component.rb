# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module IconFeature
      # A point a marketing page makes: an icon in a colored circle beside its title and body.
      # card: boxed, and stacked from md where the cards sit side by side
      class Component < ApplicationComponent
        def initialize(icon:, circle:, title:, body:, card: false)
          @icon = icon
          @circle = circle
          @title = title
          @body = body
          @card = card
        end

        private

        def wrapper_classes
          return "tw:flex tw:gap-4" unless @card

          "tw:flex tw:gap-3.5 tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white tw:p-4 tw:md:flex-col " \
            "tw:md:bg-gray-50 tw:md:p-5.5 tw:dark:border-gray-700 tw:dark:bg-gray-800"
        end
      end
    end
  end
end
