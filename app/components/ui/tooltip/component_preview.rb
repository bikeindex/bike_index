# frozen_string_literal: true

module UI::Tooltip
  class ComponentPreview < ApplicationComponentPreview
    # @!group Variants
    def default
      render(UI::Tooltip::Component.new(text: "5–9 mi")) do
        content_tag(:i, "", class: "tw:block tw:h-5 tw:w-5 tw:rounded tw:bg-purple-400 tw:dark:bg-purple-700 tw:cursor-help")
      end
    end

    def with_text_trigger
      render(UI::Tooltip::Component.new(text: "More information about this thing")) do
        "hover or focus me"
      end
    end

    def with_body_slot
      render(UI::Tooltip::Component.new) do |tooltip|
        tooltip.with_body { '<span class="tooltip-body-imperial">5 mi</span>'.html_safe }
        "body slot trigger"
      end
    end
    # @!endgroup

    # @!group Combined
    def multiple
      render_with_template(template: "ui/tooltip/preview/multiple")
    end
    # @!endgroup
  end
end
