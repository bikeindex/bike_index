# frozen_string_literal: true

module Alerts
  module FlashMessages
    class Component < ApplicationComponent
      def initialize(flash: {})
        @flash = flash
      end

      private

      def messages
        @flash.filter_map do |type, message|
          next unless message.is_a?(String)
          kind = type.to_sym
          raise ArgumentError, "Unknown flash type: #{type}" unless UI::Alert::Component::KINDS.include?(kind)
          {text: message, kind:}
        end
      end
    end
  end
end
