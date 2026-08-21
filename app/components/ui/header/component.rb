# frozen_string_literal: true

module UI
  module Header
    class Component < ApplicationComponent
      TAG_CLASSES = {h1: "tw:text-2xl", h2: "tw:text-xl", h3: "tw:text-lg"}.freeze

      # margin: false for a header whose row owns the space under it. html_class only
      # reaches the heading, so it's the one way to flatten a subtitle's margin too
      def initialize(text: nil, subtitle: nil, tag: :h1, margin: true, html_class: nil)
        @text = text
        @subtitle = subtitle
        @tag = tag
        @margin = margin
        @html_class = html_class
      end

      def call
        heading = content_tag(@tag, heading_text, class: header_classes)
        return heading if @subtitle.blank?

        safe_join([heading, content_tag(:p, @subtitle,
          class: "#{trailing_margin} tw:text-sm tw:text-gray-500 tw:dark:text-gray-400")])
      end

      private

      # An empty heading renders as an invisible, unannounced landmark rather than failing
      def heading_text
        @text.presence || content.presence ||
          raise(ArgumentError, "text: or block content is required")
      end

      def header_classes
        [TAG_CLASSES.fetch(@tag), @subtitle.present? ? "tw:mb-1" : trailing_margin,
          "tw:font-extrabold tw:tracking-tight tw:text-gray-900 tw:dark:text-gray-100",
          @html_class].compact.join(" ")
      end

      def trailing_margin = @margin ? "tw:mb-6" : "tw:mb-0"
    end
  end
end
