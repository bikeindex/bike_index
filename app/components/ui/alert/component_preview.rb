# frozen_string_literal: true

module UI
  module Alert
    class ComponentPreview < ApplicationComponentPreview
      # @!group Kind variants
      def notice
        render(UI::Alert::Component.new(text: "This is a notice alert", kind: :notice))
      end

      def error
        render(UI::Alert::Component.new(text: "This is an error alert", kind: :error))
      end

      def warning
        render(UI::Alert::Component.new(text: "This is a warning alert", kind: :warning))
      end

      def success
        render(UI::Alert::Component.new(text: "This is a success alert", kind: :success))
      end

      def custom_icon
        envelope = ActionController::Base.helpers.inline_svg_tag("icons/envelope.svg",
          class: "tw:-mb-0.5 tw:h-4 tw:w-4 tw:shrink-0", aria_hidden: true)
        render(UI::Alert::Component.new(text: "Check your email", kind: :notice, icon: envelope))
      end
      # @!endgroup

      # @!group Dismissable variants
      def dismissable_notice
        render(UI::Alert::Component.new(text: "Dismissable notice", kind: :notice, dismissable: true))
      end

      def dismissable_error
        render(UI::Alert::Component.new(text: "Dismissable error", kind: :error, dismissable: true))
      end
      # @!endgroup
    end
  end
end
