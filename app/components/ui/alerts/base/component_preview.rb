# frozen_string_literal: true

module UI
  module Alerts
    module Base
      class ComponentPreview < ApplicationComponentPreview
        CONFIRMATION_TEXT = "We've sent a confirmation link to your email. No need to wait — you can finish registering right now."
        LONG_TEXT = "Bauhaus williamsburg seitan rams 8-bit live-edge edison bulb pork belly chia. Black trumpet locavore DSA wabi-sabi fitzcarraldo angela davis. Cassavetes dad shoes japanese breakfast gatekeep truffaut, offal wolf."

        # @!group Kind variants
        def notice
          alert(kind: :notice, text: "This is a notice alert")
        end

        def notice_with_header
          alert(kind: :notice, header: "Profile hidden",
            text: text_with_link("Only you and superusers can see this profile.", "Make it public"))
        end

        def error
          alert(kind: :error, text: "This is an error alert")
        end

        def error_with_header
          alert(kind: :error, header: "Banned user",
            text: text_with_link("This profile is only visible to superusers.", "Review the ban"))
        end

        def warning
          alert(kind: :warning, text: "This is a warning alert")
        end

        def warning_with_header
          alert(kind: :warning, header: "Registration incomplete",
            text: text_with_link(CONFIRMATION_TEXT, "Resend the confirmation"))
        end

        def success
          alert(kind: :success, text: "This is a success alert")
        end

        def success_with_header
          text = ActionController::Base.helpers.safe_join([
            "You can ", link("set a password to sign in"),
            " if you prefer not to sign in via an emailed link."
          ])
          alert(kind: :success, header: "You're signed in", text:)
        end

        def purple
          alert(kind: :purple, text: CONFIRMATION_TEXT, icon: envelope_icon)
        end

        def purple_with_header
          alert(kind: :purple, header: "Check your email", icon: envelope_icon,
            text: text_with_link(CONFIRMATION_TEXT, "Resend the confirmation"))
        end
        # @!endgroup

        # @!group Dismissable variants
        def dismissable_notice
          alert(kind: :notice, text: "Dismissable notice", dismissable: true)
        end

        def dismissable_error
          alert(kind: :error, text: "Dismissable error", dismissable: true)
        end

        def dismissable_warning
          alert(kind: :warning, text: "Dismissable warning", dismissable: true)
        end

        def dismissable_success
          alert(kind: :success, text: "Dismissable success", dismissable: true)
        end

        def dismissable_purple
          alert(kind: :purple, text: LONG_TEXT, dismissable: true)
        end

        def dismissable_with_header
          alert(kind: :warning, header: "Registration incomplete", text: CONFIRMATION_TEXT, dismissable: true)
        end
        # @!endgroup

        private

        def alert(**)
          render(UI::Alerts::Base::Component.new(**))
        end

        def text_with_link(text, link_text)
          ActionController::Base.helpers.safe_join([text, " ", link(link_text)])
        end

        def link(link_text)
          ActionController::Base.helpers.link_to(link_text, "#", class: "twlink-underlined")
        end

        def envelope_icon
          ActionController::Base.helpers.inline_svg_tag("icons/envelope.svg",
            class: "tw:h-4 tw:w-4 tw:shrink-0", aria_hidden: true)
        end
      end
    end
  end
end
