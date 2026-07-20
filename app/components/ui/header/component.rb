# frozen_string_literal: true

module UI
  module Header
    class Component < ApplicationComponent
      def initialize(text:, subtitle: nil, tag: :h1, html_class: nil)
        @text = text
        @subtitle = subtitle
        @tag = tag
        @html_class = html_class
      end

      def call
        heading = content_tag(@tag, @text, class: header_classes)
        return heading if @subtitle.blank?

        safe_join([heading,
          content_tag(:p, @subtitle, class: "tw:mb-6 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400")])
      end

      private

      def header_classes
        base = case @tag
        when :h2 then "tw:text-xl"
        when :h3 then "tw:text-lg"
        else "tw:text-2xl"
        end
        margin = @subtitle.present? ? "tw:mb-1" : "tw:mb-6"
        [base, margin, "tw:font-extrabold tw:tracking-tight tw:text-gray-900 tw:dark:text-gray-100",
          @html_class].compact.join(" ")
      end
    end
  end
end
