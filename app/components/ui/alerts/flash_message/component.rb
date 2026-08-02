# frozen_string_literal: true

module UI
  module Alerts
    module FlashMessage
      class Component < ApplicationComponent
        KIND_ALIASES = {info: :notice}.freeze

        def initialize(flash: {})
          @flash = flash
        end

        def render?
          messages.any?
        end

        private

        def messages
          @messages ||= @flash.filter_map do |type, message|
            next unless message.is_a?(String)
            {text: message, kind: kind_for(type)}
          end
        end

        # Rails sweeps the flash after the layout renders, so raising here would raise again
        # on the next request too -- keep it to the environments where that's a useful signal.
        def kind_for(type)
          kind = KIND_ALIASES.fetch(type.to_sym, type.to_sym)
          return kind if UI::Alerts::Base::Component::KINDS.include?(kind)
          raise ArgumentError, "Unknown flash type: #{type}" if Rails.env.local?
          UI::Alerts::Base::Component::KINDS.first
        end
      end
    end
  end
end
