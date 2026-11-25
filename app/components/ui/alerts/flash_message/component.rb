# frozen_string_literal: true

module UI
  module Alerts
    module FlashMessage
      class Component < ApplicationComponent
        def initialize(flash: {})
          @flash = flash
        end

        private

        # Renders even when empty: #flash-messages is the turbo_stream target for
        # frame updates that carry a flash (see organized/impound_records).
        def messages
          @flash.filter_map do |type, message|
            text = text_for(message)
            next if text.blank?
            {text:, kind: type}
          end
        end

        # A hash flash names a translation in this component's sidecar and the url its link
        # points at - markup can't go in the flash itself, the cookie is JSON and drops html_safe
        def text_for(message)
          return message if message.is_a?(String)
          return unless message.is_a?(Hash)

          message = message.with_indifferent_access
          key = message[:translation_key]
          link = link_to(translation(".#{key}_link"), message[:url], class: "twlink-underlined")
          translation(".#{key}_html", link:)
        end
      end
    end
  end
end
