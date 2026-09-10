# frozen_string_literal: true

module Pages
  module Register
    module BackLink
      # The quiet "← Back" under every step's submit button
      class Component < ApplicationComponent
        def initialize(href:)
          @href = href
        end

        def call
          content_tag(:p, class: "tw:mt-3 tw:mb-0 tw:text-center") do
            link_to("← #{translation(".back")}", @href,
              class: "tw:text-sm tw:font-medium tw:text-gray-500 tw:no-underline tw:hover:text-gray-700 tw:dark:text-gray-400")
          end
        end
      end
    end
  end
end
