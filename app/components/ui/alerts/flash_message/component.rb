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
            next unless message.is_a?(String)
            {text: message, kind: type}
          end
        end
      end
    end
  end
end
