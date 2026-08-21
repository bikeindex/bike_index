# frozen_string_literal: true

module UI
  module Card
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:bg-white tw:border tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:border-gray-700"
      # A divided card's rows bring their own padding, so it has none of its own
      DIVIDED_CLASSES = "tw:rounded-xl tw:divide-y tw:divide-gray-200 tw:dark:divide-gray-700"
      UNDIVIDED_CLASSES = "tw:p-4 tw:rounded-sm"
      # Drops the side and top borders and the padding once the .twwiderow holding the card
      # is down to one column - the class carries no width of its own, so a card outside
      # such a row never bleeds
      FULL_BLEED_CLASSES = "tw:twfullbleed"

      # divided: separate the direct children with row dividers, for a checklist
      # full_bleed: meet the page's gutter once the row is single-column
      def initialize(additional_classes: nil, shadow: false, divided: false, full_bleed: false)
        @additional_classes = additional_classes
        @shadow = shadow
        @divided = divided
        @full_bleed = full_bleed
      end

      def call
        content_tag(:div, content, class: card_classes)
      end

      private

      def card_classes
        [BASE_CLASSES, @divided ? DIVIDED_CLASSES : UNDIVIDED_CLASSES,
          ("tw:shadow-sm" if @shadow), (FULL_BLEED_CLASSES if @full_bleed),
          @additional_classes].compact.join(" ")
      end
    end
  end
end
