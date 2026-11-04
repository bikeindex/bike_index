# frozen_string_literal: true

module UI
  module Card
    class Component < ApplicationComponent
      BACKGROUND_CLASSES = "tw:bg-white tw:dark:bg-gray-800"
      BASE_CLASSES = "#{BACKGROUND_CLASSES} tw:border tw:border-gray-200 tw:dark:border-gray-700"
      # In general don't use small, it looks like a hover state.
      # black is the sticker, which replaces the gray border
      SHADOWS = {
        nil => BASE_CLASSES,
        :small => "#{BASE_CLASSES} tw:shadow-sm",
        :large => "#{BASE_CLASSES} tw:shadow-[0_10px_30px_rgba(44,62,80,.16)]",
        :black => "#{BACKGROUND_CLASSES} tw:border-3 tw:border-[#111] tw:shadow-[4px_4px_0_#111] tw:dark:border-gray-300 tw:dark:shadow-[4px_4px_0_var(--tw-color-gray-300)]"
      }.freeze
      # A divided card's rows bring their own padding, so it has none of its own
      DIVIDED_CLASSES = "tw:rounded-xl tw:divide-y tw:divide-gray-200 tw:dark:divide-gray-700"
      UNDIVIDED_CLASSES = "tw:p-4"
      ROUNDED_LG_SHADOWS = %i[large black].freeze

      # divided: separate the direct children with row dividers, for a checklist
      # full_bleed: meet the page's gutter once the .twwiderow holding it is single-column,
      #   and nothing outside such a row
      def initialize(additional_classes: nil, shadow: nil, divided: false, full_bleed: false)
        @shadow_classes = SHADOWS.fetch(shadow) { raise ArgumentError, "unknown shadow #{shadow.inspect}, expected one of: #{SHADOWS.keys.inspect}" }
        @rounded = ROUNDED_LG_SHADOWS.include?(shadow) ? "tw:rounded-lg" : "tw:rounded-sm"
        @additional_classes = additional_classes
        @divided = divided
        @full_bleed = full_bleed
      end

      def call
        content_tag(:div, content, class: card_classes)
      end

      private

      def card_classes
        [@shadow_classes, @divided ? DIVIDED_CLASSES : "#{UNDIVIDED_CLASSES} #{@rounded}",
          ("tw:twfullbleed" if @full_bleed), @additional_classes].compact.join(" ")
      end
    end
  end
end
