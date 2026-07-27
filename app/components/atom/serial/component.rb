# frozen_string_literal: true

module Atom
  module Serial
    # Renders a bike's serial as seen by the given user. A hidden, unknown or
    # absent serial renders that word in place of the number, and a hidden serial
    # is followed by why it's hidden unless skip_explanation.
    class Component < ApplicationComponent
      # What serial_display returns in place of a number
      PLACEHOLDERS = ["hidden", "unknown", "made without serial"].freeze

      def initialize(bike:, user: nil, skip_explanation: false)
        @bike = bike
        @user = user
        @skip_explanation = skip_explanation
      end

      def render?
        serial.present?
      end

      def call
        return serial_block unless explanation?

        safe_join([serial_block, " ", explanation])
      end

      private

      def serial
        @serial ||= @bike.serial_display(@user)
      end

      def placeholder?
        PLACEHOLDERS.include?(serial.downcase)
      end

      def serial_block
        return content_tag(:span, serial, class: "serial-span") unless placeholder?

        content_tag(:span, translation(".#{serial.downcase.tr(" ", "_")}"), class: "less-strong")
      end

      def explanation?
        @bike.serial_hidden? && !@skip_explanation
      end

      def explanation
        content_tag(:em, explanation_text, class: "small less-less-strong")
      end

      def explanation_text
        return translation(".hidden_for_unauthorized_users") if @bike.authorized?(@user)

        translation(".hidden_because_status", bike_type: @bike.type, status: @bike.status_humanized_translated)
      end
    end
  end
end
