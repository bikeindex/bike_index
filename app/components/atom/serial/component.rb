# frozen_string_literal: true

module Atom
  module Serial
    # Renders a bike's serial as seen by the given user. A hidden, unknown or
    # absent serial renders that word in place of the number, and a hidden serial
    # is followed by why it's hidden unless skip_explanation.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:font-mono tw:p-0 tw:bg-transparent tw:text-inherit tw:rounded-none"
      # What serial_display returns in place of a number
      PLACEHOLDERS = ["hidden", "unknown", "made without serial"].freeze
      # BikeHelper#render_serial_display renders serials everywhere else, so borrow its keys
      TRANSLATION_SCOPE = %i[helpers bike_helper].freeze

      def initialize(bike:, user: nil, skip_explanation: false)
        @bike = bike
        @user = user
        @skip_explanation = skip_explanation
      end

      def render?
        serial.present?
      end

      def call
        safe_join([serial_block, explanation].compact, " ")
      end

      private

      def serial
        @serial ||= @bike.serial_display(@user)
      end

      def placeholder?
        PLACEHOLDERS.include?(serial.downcase)
      end

      def serial_block
        return content_tag(:span, translation(serial.downcase.tr(" ", "_"), scope: TRANSLATION_SCOPE), class: "tw:opacity-65") if placeholder?

        content_tag(:code, serial, class: BASE_CLASSES)
      end

      def explanation
        return unless @bike.serial_hidden? && !@skip_explanation

        content_tag(:em, explanation_text, class: "tw:text-sm tw:opacity-65")
      end

      def explanation_text
        return translation(:hidden_for_unauthorized_users, scope: TRANSLATION_SCOPE) if @bike.authorized?(@user)

        translation(:hidden_because_status, bike_type: @bike.type,
          status: @bike.status_humanized_translated, scope: TRANSLATION_SCOPE)
      end
    end
  end
end
