# frozen_string_literal: true

module UI
  module Header
    class Component < ApplicationComponent
      TAG_CLASSES = {h2: "tw:text-xl", h3: "tw:text-lg", h4: "tw:text-base",
                     h5: "tw:text-sm", h6: "tw:text-xs"}.freeze

      def initialize(text: nil, subtitle: nil, tag: :h1, html_class: nil)
        @text = text
        @subtitle = subtitle
        @tag = tag
        @html_class = html_class
      end

      def call
        heading = content_tag(@tag, @text.presence || content, class: header_classes)
        return heading if @subtitle.blank?

        safe_join([heading,
          content_tag(:p, @subtitle, class: "tw:mb-6 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400")])
      end

      private

      def header_classes
        [TAG_CLASSES.fetch(@tag, "tw:text-2xl"), @subtitle.present? ? "tw:mb-1" : "tw:mb-6",
          "tw:font-extrabold tw:tracking-tight tw:text-gray-900 tw:dark:text-gray-100",
          @html_class].compact.join(" ")
      end
    end
  end
end
