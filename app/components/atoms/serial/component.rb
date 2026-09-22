# frozen_string_literal: true

module Atoms
  module Serial
    # Renders a bike's serial as seen by the given user. A hidden, unknown or
    # absent serial renders that word in place of the number, and a hidden serial
    # is followed by why it's hidden - inline, or in a tooltip.
    # Pass a bike, or a raw serial string.
    class Component < ApplicationComponent
      # What serial_display returns in place of a number
      PLACEHOLDERS = ["hidden", "unknown", "made without serial"].freeze

      def initialize(bike: nil, serial: nil, user: nil, explanation: :inline, html_class: nil)
        @bike = bike
        @serial = serial
        @user = user
        @explanation = explanation
        @html_class = html_class
      end

      def render?
        serial.present?
      end

      def call
        return serial_block unless explanation?

        safe_join([serial_block, " ", explanation_block])
      end

      private

      def serial
        @serial ||= @bike&.serial_display(@user)
      end

      # A passed serial is whatever was searched for, so "unknown" means the number
      def placeholder?
        @bike.present? && PLACEHOLDERS.include?(serial.downcase)
      end

      def serial_block
        return content_tag(:span, serial, class: ["serial-span", @html_class]) unless placeholder?

        content_tag(:span, placeholder_text, class: ["less-strong", @html_class])
      end

      def placeholder_text
        case serial.downcase
        when "hidden" then translation(".hidden")
        when "made without serial" then translation(".made_without_serial")
        else translation(".unknown")
        end
      end

      def explanation?
        @bike&.serial_hidden?
      end

      def explanation_block
        return render(UI::Tooltip::Component.new(text: explanation_text)) if @explanation == :tooltip

        content_tag(:em, explanation_text, class: "small less-less-strong")
      end

      def explanation_text
        return translation(".hidden_for_unauthorized_users") if @bike.authorized?(@user)

        translation(".hidden_because_status", bike_type: @bike.type, status: @bike.status_humanized_translated)
      end
    end
  end
end
