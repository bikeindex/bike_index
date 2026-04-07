# frozen_string_literal: true

module Alerts
  module FlashMessages
    class ComponentPreview < ApplicationComponentPreview
      def notice
        render(Alerts::FlashMessages::Component.new(flash: {notice: "Successfully updated!"}))
      end

      def error
        render(Alerts::FlashMessages::Component.new(flash: {error: "Something went wrong"}))
      end

      def multiple
        render(Alerts::FlashMessages::Component.new(flash: {notice: "Saved successfully", error: "But there was a warning"}))
      end
    end
  end
end
