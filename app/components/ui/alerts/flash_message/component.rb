# frozen_string_literal: true

module UI
  module Alerts
    module FlashMessage
      class Component < ApplicationComponent
        def initialize(flash: {})
          @flash = flash
        end

        private

        def messages
          @flash.filter_map do |type, message|
            next unless message.is_a?(String)
            kind, text = helpers.flash_kind_and_body(type, message)
            raise ArgumentError, "Unknown flash type: #{type}" unless UI::Alert::Component::KINDS.include?(kind)
            {text:, kind:}
          end
        end
      end
    end
  end
end
