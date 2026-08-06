# frozen_string_literal: true

module Register
  module Page
    # Full-bleed gray shell for the registration flow pages. The negative margins pull
    # over the layout's nav/footer spacing so the gray runs edge to edge; content is
    # centered at form width. flush_top: false keeps the top margin when there's a heading
    # above it (the org preview), so it isn't pulled over.
    class Component < ApplicationComponent
      # data: for a step-wide controller, since this wraps everything on the page
      # (register--heading needs both the heading and the form in scope)
      def initialize(data: {}, flush_top: true)
        @data = data
        @flush_top = flush_top
      end

      def call
        content_tag(:div,
          content_tag(:div, content, class: "tw:mx-auto tw:max-w-md"),
          class: shell_classes,
          data: @data.merge(controller: ["register--revalidate", @data[:controller]].compact.join(" ")))
      end

      private

      def shell_classes
        classes = "tw:-mb-18 tw:bg-gray-100 tw:px-4 tw:py-10 tw:dark:bg-gray-900"
        @flush_top ? "tw:-mt-9 tw:min-[992px]:-mt-15 #{classes}" : classes
      end
    end
  end
end
