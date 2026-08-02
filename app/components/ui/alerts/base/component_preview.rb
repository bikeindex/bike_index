# frozen_string_literal: true

module UI
  module Alerts
    module Base
      class ComponentPreview < ApplicationComponentPreview
        CONFIRMATION_TEXT = "We've sent a confirmation link to your email. No need to wait — you can finish registering right now."

        # @!group Kind variants
        def notice
          render(UI::Alerts::Base::Component.new(text: "This is a notice alert", kind: :notice))
        end

        def error
          render(UI::Alerts::Base::Component.new(text: "This is an error alert", kind: :error))
        end

        def warning
          render(UI::Alerts::Base::Component.new(text: "This is a warning alert", kind: :warning))
        end

        def success
          render(UI::Alerts::Base::Component.new(text: "This is a success alert", kind: :success))
        end

        def purple
          render(UI::Alerts::Base::Component.new(text: CONFIRMATION_TEXT, kind: :purple))
        end

        def custom_icon
          envelope = ActionController::Base.helpers.inline_svg_tag("icons/envelope.svg",
            class: "tw:-mb-0.5 tw:h-4 tw:w-4 tw:shrink-0", aria_hidden: true)
          render(UI::Alerts::Base::Component.new(text: "Check your email", kind: :notice, icon: envelope))
        end
        # @!endgroup

        # @!group Header variants
        def with_header
          render(UI::Alerts::Base::Component.new(header: "Registration incomplete", kind: :warning, text: CONFIRMATION_TEXT))
        end

        def dismissable_with_header
          render(UI::Alerts::Base::Component.new(header: "Registration incomplete", kind: :warning, text: CONFIRMATION_TEXT,
            dismissable: true))
        end
        # @!endgroup

        # @!group Dismissable variants
        def dismissable_notice
          render(UI::Alerts::Base::Component.new(text: "Dismissable notice", kind: :notice, dismissable: true))
        end

        def dismissable_error
          render(UI::Alerts::Base::Component.new(text: "Dismissable error", kind: :error, dismissable: true))
        end
        # @!endgroup
      end
    end
  end
end
