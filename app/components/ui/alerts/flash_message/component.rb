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
            {text: message, kind: kind_for(type)}
          end
        end

        # Rails sweeps the flash after the layout renders, so raising here would raise again
        # on the next request too -- keep it to the environments where that's a useful signal.
        def kind_for(type)
          kind = type.to_sym
          return kind if UI::Alerts::Base::Component::KINDS.include?(kind)
          raise ArgumentError, "Unknown flash type: #{type}" if Rails.env.local?
          UI::Alerts::Base::Component::KINDS.first
        end
      end
    end
  end
end
