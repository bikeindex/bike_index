# frozen_string_literal: true

module Pages
  module Register
    module Parts
      module BackLink
        # The quiet "← Back" under every step's submit button
        class Component < ApplicationComponent
          def initialize(href:)
            @href = href
          end

          def render? = @href.present?

          def call
            content_tag(:p, class: "tw:mt-3 tw:mb-0 tw:text-center") do
              render(UI::ButtonLink::Component.new(href: @href, text: "← #{translation(".back")}", color: :link_gray,
                html_class: "tw:text-sm tw:font-medium"))
            end
          end
        end
      end
    end
  end
end
