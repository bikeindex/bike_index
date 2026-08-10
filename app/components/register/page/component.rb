# frozen_string_literal: true

module Register
  module Page
    # Full-bleed gray shell for the registration flow pages. The negative
    # margins pull over the layout's nav/footer spacing so the gray runs
    # edge to edge; content is centered at form width.
    class Component < ApplicationComponent
      # data: for a step-wide controller, since this wraps everything on the page
      # (register--heading needs both the heading and the form in scope).
      # wide: for a page that isn't a form - the finished theft report's checklist
      def initialize(data: {}, wide: false)
        @data = data
        @wide = wide
      end

      def call
        content_tag(:div,
          content_tag(:div, content, class: "tw:mx-auto #{@wide ? "tw:max-w-3xl" : "tw:max-w-md"}"),
          class: "tw:-mt-9 tw:-mb-18 tw:bg-gray-100 tw:px-4 tw:py-10 tw:min-[992px]:-mt-15 tw:dark:bg-gray-900",
          data: @data.merge(controller: ["register--revalidate", @data[:controller]].compact.join(" ")))
      end
    end
  end
end
