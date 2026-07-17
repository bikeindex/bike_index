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
      end
    end
  end
end
