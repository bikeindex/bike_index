# frozen_string_literal: true

module Register
  module Page
    # Full-bleed gray shell for the registration flow pages. The negative
    # margins pull over the layout's nav/footer spacing so the gray runs
    # edge to edge; content is centered at form width.
    class Component < ApplicationComponent
      def call
        content_tag(:div,
          content_tag(:div, content, class: "tw:mx-auto tw:max-w-md"),
          class: "tw:-mt-9 tw:-mb-18 tw:bg-gray-100 tw:px-4 tw:py-10 tw:min-[992px]:-mt-15 tw:dark:bg-gray-900",
          data: {controller: "register--revalidate"})
      end
    end
  end
end
