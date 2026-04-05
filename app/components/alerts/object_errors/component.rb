# frozen_string_literal: true

module Alerts
  module ObjectErrors
    class Component < ApplicationComponent
      def initialize(object:, name: nil, error_messages: nil, dismissable: false)
        @object = object
        @name = name || @object.class.name.titleize
        @error_messages = error_messages || @object.errors.full_messages
        @dismissable = dismissable
      end

      def render?
        @error_messages.any?
      end

      private

      def header_text
        count = @error_messages.count
        "#{count} #{"error".pluralize(count)} prevented this #{@name} from being saved:"
      end
    end
  end
end
