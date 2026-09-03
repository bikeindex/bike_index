# frozen_string_literal: true

module UI
  module Alerts
    module FlashMessage
      class ComponentPreview < ApplicationComponentPreview
        def notice
          render(UI::Alerts::FlashMessage::Component.new(flash: {notice: "Successfully updated!"}))
        end

        def error
          render(UI::Alerts::FlashMessage::Component.new(flash: {error: "Something went wrong"}))
        end

        def multiple
          render(UI::Alerts::FlashMessage::Component.new(flash: {notice: "Saved successfully", error: "But there was a warning"}))
        end

        # A hash flash names a translation and the url its link points at, rather than
        # carrying markup through the cookie
        def with_link
          render(UI::Alerts::FlashMessage::Component.new(flash: {
            notice: {translation_key: :signed_in, url: "/users/update_password_form_with_reset_token"}
          }))
        end
      end
    end
  end
end
