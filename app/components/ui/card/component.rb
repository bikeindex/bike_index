# frozen_string_literal: true

module UI
  module Card
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:bg-white tw:border tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:border-gray-700"
      # A divided card's rows bring their own padding, so it has none of its own
      DIVIDED_CLASSES = "tw:rounded-xl tw:divide-y tw:divide-gray-200 tw:dark:divide-gray-700"
      UNDIVIDED_CLASSES = "tw:p-4 tw:rounded-sm"
      # A card whose content should meet the page's own gutter rather than sit inset inside
      # it twice over. The top goes with the sides, so a stack of these reads as one rule
      # between each pair rather than two
      MOBILE_FLUSH_CLASSES = "tw:max-md:border-x-0 tw:max-md:border-t-0 tw:max-md:px-0"

      # divided: separate the direct children with row dividers, for a checklist
      # mobile_flush: drop the top and side borders, and the padding, below md
      def initialize(additional_classes: nil, shadow: false, divided: false, mobile_flush: false)
        @additional_classes = additional_classes
        @shadow = shadow
        @divided = divided
        @mobile_flush = mobile_flush
      end

      def call
        content_tag(:div, content, class: card_classes)
      end

      private

      def card_classes
        [BASE_CLASSES, @divided ? DIVIDED_CLASSES : UNDIVIDED_CLASSES,
          ("tw:shadow-sm" if @shadow), (MOBILE_FLUSH_CLASSES if @mobile_flush),
          @additional_classes].compact.join(" ")
      end
    end
  end
end
