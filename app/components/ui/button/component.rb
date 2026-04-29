# frozen_string_literal: true

module UI
  module Button
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-flex tw:items-center tw:gap-1.5 tw:rounded-lg tw:cursor-pointer tw:transition-colors"

      SIZES = {
        sm: "tw:px-2.5 tw:py-1 tw:text-xs",
        md: "tw:px-3 tw:py-1.5 tw:text-sm",
        lg: "tw:px-4 tw:py-2 tw:text-base"
      }.freeze

      COLORS = {
        primary: "tw:text-white tw:bg-blue-600 tw:border tw:border-blue-600 tw:hover:bg-blue-700 tw:active:bg-blue-800 tw:focus:ring-blue-500/40 tw:dark:bg-blue-500 tw:dark:border-blue-500 tw:dark:hover:bg-blue-600 tw:dark:active:bg-blue-700",
        secondary: "tw:text-gray-700 tw:bg-gray-50 tw:border tw:border-gray-300 tw:hover:bg-gray-100 tw:hover:border-gray-400 tw:active:bg-gray-200 tw:focus:ring-blue-500/40 tw:dark:text-gray-200 tw:dark:bg-gray-700 tw:dark:border-gray-500 tw:dark:hover:bg-gray-800 tw:dark:hover:border-gray-600 tw:dark:active:bg-gray-900",
        error: "tw:text-white tw:bg-red-600 tw:border tw:border-red-600 tw:hover:bg-red-700 tw:active:bg-red-800 tw:focus:ring-red-500/40 tw:dark:bg-red-500 tw:dark:border-red-500 tw:dark:hover:bg-red-600 tw:dark:active:bg-red-700",
        link: "tw:text-blue-600 tw:hover:text-blue-800 tw:dark:text-blue-400 tw:dark:hover:text-blue-300 tw:underline tw:active:text-blue-800 tw:active:dark:text-blue-300 tw:active:font-bold tw:p-0 tw:focus:outline-none"
      }.freeze

      ACTIVE_COLORS = {
        primary: "tw:ring-2 tw:ring-blue-500/40 tw:bg-blue-700 tw:dark:bg-blue-600",
        secondary: "tw:ring-2 tw:ring-blue-500/40 tw:bg-gray-100 tw:border-gray-400 tw:dark:bg-gray-800 tw:dark:border-gray-600",
        error: "tw:ring-2 tw:ring-red-500/40 tw:bg-red-700 tw:dark:bg-red-600",
        link: "tw:text-blue-800 tw:dark:text-blue-300 tw:font-bold"
      }.freeze

      KINDS = %i[button submit]

      def self.build_classes(color:, size:, active: false, html_class: nil)
        classes = [BASE_CLASSES, COLORS[color], html_class]
        unless color == :link
          classes << SIZES[size]
          classes << "tw:focus:outline-none tw:focus:ring-3 tw:font-medium"
        end
        classes << ACTIVE_COLORS[color] if active
        classes.compact.join(" ")
      end

      def initialize(text: nil, color: :secondary, size: :md, active: false, html_class: nil, kind: nil, data: {})
        @text = text
        @color = COLORS.key?(color) ? color : :secondary
        @kind = KINDS.include?(kind&.to_sym) ? kind.to_sym : KINDS.first
        @active = active
        @html_class = html_class
        @data = data

        @size = SIZES.key?(size) ? size : :md
        raise ArgumentError, "size is not supported for link color" if @color == :link && @size != :md
      end

      def call
        content_tag(:button, @text || content, class: button_classes, type: (@kind == :submit) ? "submit" : "button", data: @data)
      end

      def button_classes
        self.class.build_classes(color: @color, size: @size, active: @active, html_class: @html_class)
      end
    end
  end
end
