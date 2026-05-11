# frozen_string_literal: true

module UI
  module Header
    class Component < ApplicationComponent
      def initialize(text:, tag: :h1, html_class: nil)
        @text = text
        @tag = tag
        @html_class = html_class
      end

      def call
        content_tag(@tag, @text, class: header_classes)
      end

      private

      def header_classes
        base = case @tag
        when :h1 then "tw:text-2xl"
        when :h2 then "tw:text-xl"
        when :h3 then "tw:text-lg"
        else "tw:text-2xl"
        end
        [base, "tw:font-bold tw:text-gray-900 tw:dark:text-white tw:mb-6", @html_class].compact.join(" ")
      end
    end
  end
end
